import { util } from '@kit.ArkTS';
import { fileIo } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';

import {
  CategoryComicsResult,
  CategoryItem,
  Comic,
  ComicChapter,
  ComicComment,
  ComicInfoResult,
  ComicTagGroup,
  ExploreMixedBlock,
  ExplorePageLoadResult,
  ExplorePageMeta,
  CategoryPageMeta,
  ExploreSection,
  FavoriteFoldersResult,
  InstalledComicSource,
  NetworkFavoriteMeta,
  RankingPageInfo,
  SearchOptionDef,
  SearchPageSourceItem,
  SearchSuggestionContext,
  SourceAccountConfig,
  SourceSettingDef,
  SourceSettingOption
} from '../models/ComicModels';
import { SourceScriptUtil } from '../utils/SourceScriptUtil';

import { JsMessageHost, JsMessagePayload } from './JsMessageHost';

import { JsNativeRuntime } from './JsNativeRuntime';



export interface JsEngineStatus {

  initLoaded: boolean;

  initScriptLength: number;

  stagedSourceCount: number;

  runtimeReady: boolean;

  runtimeNote: string;

}



/**

 * QuickJS 漫画源运行时桥接（API 23 NAPI + JsMessageHost）。

 */

export class JsEngineBridge {

  private static instance: JsEngineBridge;
  private static readonly utf8Decoder = new util.TextDecoder('utf-8');

  private initReady: boolean = false;

  private runtimeReady: boolean = false;

  private initScript: string = '';

  private stagedSources: Map<string, string> = new Map();

  /** 已编译进 QuickJS 的 source key，避免批量安装时重复 load */
  private loadedNativeKeys: Set<string> = new Set();

  private sourcesPath: string = '';



  static getInstance(): JsEngineBridge {

    if (!JsEngineBridge.instance) {

      JsEngineBridge.instance = new JsEngineBridge();

    }

    return JsEngineBridge.instance;

  }



  async init(context: common.UIAbilityContext): Promise<void> {

    this.sourcesPath = `${context.filesDir}/comic_sources`;

    try {

      const buf = await context.resourceManager.getRawFileContent('init.js');

      this.initScript = JsEngineBridge.bytesToString(new Uint8Array(buf));

      this.initReady = this.initScript.length > 0;

      console.info(`[JsEngineBridge] init.js loaded (${this.initScript.length} chars)`);

    } catch (e) {

      console.error(`[JsEngineBridge] failed to load init.js: ${e}`);

      this.initScript = '';

      this.initReady = false;

    }

    if (this.initReady && JsNativeRuntime.isAvailable()) {
      await JsEngineBridge.yieldToUi();
      this.runtimeReady = JsNativeRuntime.initRuntime(this.initScript);
      console.info(`[JsEngineBridge] QuickJS runtime ready=${this.runtimeReady}`);
    }

    // 图源脚本延后到 AppBootstrap 后台装入，避免启动/首帧阻塞主线程

  }



  private static bytesToString(bytes: Uint8Array): string {
    return JsEngineBridge.utf8Decoder.decodeToString(bytes);
  }



  isReady(): boolean {

    return this.initReady;

  }



  getStatus(): JsEngineStatus {

    return {

      initLoaded: this.initReady,

      initScriptLength: this.initScript.length,

      stagedSourceCount: this.stagedSources.size,

      runtimeReady: this.runtimeReady,

      runtimeNote: this.runtimeReady ?

        'QuickJS NAPI 已就绪（HTTP: RCP FetchSync）' :

        'init.js 已载入；设备未加载 libvenera_qjs.so'

    };

  }



  getStagedSourceKeys(): string[] {

    return Array.from(this.stagedSources.keys());

  }



  isSourceStaged(sourceKey: string): boolean {

    return this.stagedSources.has(sourceKey);

  }

  isSourceLoadedInNative(sourceKey: string): boolean {

    return this.loadedNativeKeys.has(sourceKey);

  }

  /** staged 内存或沙箱 .js 中的图源脚本正文 */
  getStagedScriptContent(sourceKey: string): string {

    const cached = this.stagedSources.get(sourceKey) ?? '';

    if (cached.length > 0) {

      return cached;

    }

    return this.readCachedSourceScript(sourceKey, this.sourcesPath);

  }

  /** 仅写入 staged 映射，不触发 QuickJS 编译（批量安装用） */
  stageSourceScript(sourceKey: string, scriptContent: string): void {

    if (scriptContent.length === 0 || sourceKey.length === 0) {

      return;

    }

    this.stagedSources.set(sourceKey, scriptContent);

  }

  private static yieldToUi(): Promise<void> {

    return new Promise<void>((resolve) => {

      setTimeout(() => resolve(), 16);

    });

  }



  async dispatchMessage(payload: JsMessagePayload): Promise<Object | null> {

    return JsMessageHost.getInstance().handle(payload);

  }



  buildSearchScript(sourceKey: string, keyword: string, options: string[], page: number): string {
    const safeKey = JsEngineBridge.escapeJs(sourceKey);
    const safeWord = JsEngineBridge.escapeJs(keyword);
    const safeOpts = JSON.stringify(options);
    return `(async function(){var src=ComicSource.sources[${safeKey}];` +
      `if(!src||!src.search||!src.search.load)return {comics:[],maxPage:1};` +
      `var res=await src.search.load(${safeWord},${safeOpts},${page});` +
      `if(!res)return {comics:[],maxPage:1};return {comics:res.comics||[],maxPage:res.maxPage||1};})()`;
  }

  buildCategoriesScript(sourceKey: string): string {
    const safeKey = JsEngineBridge.escapeJs(sourceKey);
    return `(function(){var src=ComicSource.sources[${safeKey}];if(!src||!src.category||!src.category.parts)return[];var out=[];for(var pi=0;pi<src.category.parts.length;pi++){var part=src.category.parts[pi];var itemType=part.itemType||'category';var gp=part.groupParam;` +
      `if(part.categories&&Array.isArray(part.categories)){for(var ci=0;ci<part.categories.length;ci++){var c=part.categories[ci];var label=typeof c==='string'?c:(c&&c.label?c.label:'');if(!label)continue;var param='';` +
      `if(part.categoryParams&&part.categoryParams[ci]!=null)param=String(part.categoryParams[ci]);else if(gp!=null)param=String(gp);else if(typeof c==='object'&&c.param)param=String(c.param);` +
      `out.push({label:label,param:param,partName:part.name||'',itemType:itemType});}}else if(part.name){out.push({label:part.name,param:gp?String(gp):'',partName:part.name,itemType:itemType});}}return out;})()`;
  }

  buildCategoryComicsScript(sourceKey: string, category: string, param: string, page: number): string {
    const safeKey = JsEngineBridge.escapeJs(sourceKey);
    const safeCat = JsEngineBridge.escapeJs(category);
    const paramJs = param.length > 0 ? JsEngineBridge.escapeJs(param) : 'null';
    return `(async function(){var src=ComicSource.sources[${safeKey}];if(!src||!src.categoryComics||!src.categoryComics.load)return {comics:[],maxPage:1};` +
      `var p=${paramJs};var res=await src.categoryComics.load(${safeCat},p,[],${page});` +
      `if(!res)return {comics:[],maxPage:1};return {comics:res.comics||[],maxPage:res.maxPage||1};})()`;
  }

  buildCategorySearchScript(sourceKey: string, keyword: string, page: number, options: string[]): string {
    const safeKey = JsEngineBridge.escapeJs(sourceKey);
    const safeWord = JsEngineBridge.escapeJs(keyword);
    const safeOpts = JSON.stringify(options);
    return `(async function(){var src=ComicSource.sources[${safeKey}];if(!src||!src.search||!src.search.load)return {comics:[],maxPage:1};` +
      `var res=await src.search.load(${safeWord},${safeOpts},${page});if(!res)return {comics:[],maxPage:1};` +
      `return {comics:res.comics||[],maxPage:res.maxPage||1};})()`;
  }

  buildComicChaptersScript(sourceKey: string, comicId: string): string {
    const safeKey = JsEngineBridge.escapeJs(sourceKey);
    const safeComic = JsEngineBridge.escapeJs(comicId);
    return `(async function(){var src=ComicSource.sources[${safeKey}];if(!src||!src.comic||!src.comic.loadInfo)return null;var info=await src.comic.loadInfo(${safeComic});return(info&&info.chapters)?info.chapters:null;})()`;
  }

  buildExploreScript(sourceKey: string): string {
    const safeKey = JsEngineBridge.escapeJs(sourceKey);
    return `(async function(){var src=ComicSource.sources[${safeKey}];` +
      `if(!src||!src.explore||!src.explore.length)return [];` +
      `var sections=[];` +
      `for(var ei=0;ei<src.explore.length;ei++){` +
      `var exp=src.explore[ei];if(!exp||typeof exp.load!=='function')continue;` +
      `try{var data=await exp.load();if(!data)continue;` +
      `if(Array.isArray(data)){if(data.length>0)sections.push({title:exp.title||'推荐',comics:data});}` +
      `else if(typeof data==='object'){var keys=Object.keys(data);` +
      `for(var ki=0;ki<keys.length;ki++){var arr=data[keys[ki]];` +
      `if(Array.isArray(arr)&&arr.length>0)sections.push({title:keys[ki],comics:arr});}}}` +
      `catch(e){}}return sections;})()`;
  }

  buildListExplorePageTitlesScript(): string {
    return `(function(){var out=[];var keys=Object.keys(ComicSource.sources);` +
      `for(var i=0;i<keys.length;i++){var src=ComicSource.sources[keys[i]];` +
      `if(!src||!src.explore||!src.explore.length)continue;` +
      `for(var j=0;j<src.explore.length;j++){var exp=src.explore[j];` +
      `if(exp&&exp.title&&out.indexOf(exp.title)<0)out.push(exp.title);}}return out;})()`;
  }

  buildListExplorePageMetaScript(): string {
    return `(function(){var out=[];var keys=Object.keys(ComicSource.sources);` +
      `for(var i=0;i<keys.length;i++){var sk=keys[i];var src=ComicSource.sources[sk];` +
      `if(!src||!src.explore||!src.explore.length)continue;` +
      `for(var j=0;j<src.explore.length;j++){var exp=src.explore[j];` +
      `if(exp&&exp.title)out.push({title:exp.title,sourceKey:sk});}}return out;})()`;
  }

  buildListCategoryPageMetaScript(): string {
    return `(function(){var out=[];var keys=Object.keys(ComicSource.sources);` +
      `for(var i=0;i<keys.length;i++){var sk=keys[i];var src=ComicSource.sources[sk];` +
      `if(!src||!src.category||!src.category.key)continue;` +
      `out.push({key:src.category.key,title:src.category.title||src.name,sourceKey:sk});}` +
      `return out;})()`;
  }

  buildExploreByTitleScript(title: string, page: number, nextCursor: string): string {
    const safeTitle = JsEngineBridge.escapeJs(title);
    const safeNext = JsEngineBridge.escapeJs(nextCursor);
    return `(async function(){var want=${safeTitle};var pageNum=${page};var nextIn=${safeNext};` +
      `function serVm(v){if(v==null)return'';try{return JSON.stringify(v);}catch(e){return'';}}` +
      `var keys=Object.keys(ComicSource.sources);` +
      `for(var si=0;si<keys.length;si++){var sourceKey=keys[si];var src=ComicSource.sources[sourceKey];` +
      `if(!src||!src.explore)continue;` +
      `for(var ei=0;ei<src.explore.length;ei++){var exp=src.explore[ei];` +
      `if(!exp||exp.title!==want)continue;` +
      `var typ=exp.type||'multiPartPage';` +
      `try{` +
      `if(typ==='multiPageComicList'){` +
      `if(typeof exp.load==='function'){var data=await exp.load(pageNum);` +
      `return{sourceKey:sourceKey,title:want,sections:[],comics:(data&&data.comics)||[],` +
      `mixedBlocks:[],maxPage:(data&&data.maxPage)||1,page:pageNum,nextCursor:''};}` +
      `if(typeof exp.loadNext==='function'){var nc=nextIn.length>0?nextIn:null;` +
      `var data2=await exp.loadNext(nc);` +
      `return{sourceKey:sourceKey,title:want,sections:[],comics:(data2&&data2.comics)||[],` +
      `mixedBlocks:[],maxPage:1,page:pageNum,nextCursor:(data2&&data2.next)||''};}}` +
      `if(typ==='mixed'&&typeof exp.load==='function'){var mix=await exp.load(pageNum-1);` +
      `var blocks=[];var arr=(mix&&mix.data)||[];` +
      `for(var bi=0;bi<arr.length;bi++){var el=arr[bi];` +
      `if(Array.isArray(el))blocks.push({kind:'grid',title:'',comics:el,viewMoreJson:''});` +
      `else if(el&&el.comics)blocks.push({kind:'section',title:el.title||'',comics:el.comics,` +
      `viewMoreJson:serVm(el.viewMore)});}` +
      `return{sourceKey:sourceKey,title:want,sections:[],comics:[],mixedBlocks:blocks,` +
      `maxPage:(mix&&mix.maxPage)||1,page:pageNum,nextCursor:''};}` +
      `if(typeof exp.load!=='function')continue;` +
      `var data3=await exp.load();var sections=[];` +
      `if(!data3)return{sourceKey:sourceKey,title:want,sections:[],comics:[],mixedBlocks:[],` +
      `maxPage:1,page:pageNum,nextCursor:''};` +
      `if(Array.isArray(data3)&&data3.length>0&&data3[0]&&data3[0].comics){` +
      `for(var pi=0;pi<data3.length;pi++){var p=data3[pi];if(p&&p.comics&&p.comics.length)` +
      `sections.push({title:p.title||'',comics:p.comics,viewMoreJson:serVm(p.viewMore)});}}` +
      `else if(Array.isArray(data3)&&data3.length>0)` +
      `{sections.push({title:exp.title||want,comics:data3,viewMoreJson:''});}` +
      `else if(typeof data3==='object'){var dkeys=Object.keys(data3);` +
      `for(var ki=0;ki<dkeys.length;ki++){var a=data3[dkeys[ki]];` +
      `if(Array.isArray(a)&&a.length>0)sections.push({title:dkeys[ki],comics:a,viewMoreJson:''});}}` +
      `return{sourceKey:sourceKey,title:want,sections:sections,comics:[],mixedBlocks:[],` +
      `maxPage:1,page:pageNum,nextCursor:''};` +
      `}catch(e){return{sourceKey:sourceKey,title:want,sections:[],comics:[],mixedBlocks:[],` +
      `maxPage:1,page:pageNum,nextCursor:'',error:String(e)};}}}` +
      `return null;})()`;
  }

  buildSearchableSourcesScript(): string {
    return `(function(){var out=[];var keys=Object.keys(ComicSource.sources);` +
      `for(var i=0;i<keys.length;i++){var k=keys[i];var src=ComicSource.sources[k];` +
      `if(src&&src.search&&typeof src.search.load==='function')out.push(k);}return out;})()`;
  }

  buildListRankingPagesScript(): string {
    return `(function(){var out=[];var keys=Object.keys(ComicSource.sources);` +
      `for(var i=0;i<keys.length;i++){var k=keys[i];var src=ComicSource.sources[k];` +
      `if(src&&src.category&&src.category.enableRankingPage&&src.categoryComics&&` +
      `src.categoryComics.ranking&&typeof src.categoryComics.ranking.load==='function'){` +
      `out.push({sourceKey:k,categoryTitle:src.category.title||src.name,` +
      `options:src.categoryComics.ranking.options||[]});}}return out;})()`;
  }

  buildRankingComicsScript(sourceKey: string, option: string, page: number): string {
    const safeKey = JsEngineBridge.escapeJs(sourceKey);
    const safeOption = JsEngineBridge.escapeJs(option);
    return `(async function(){var src=ComicSource.sources[${safeKey}];` +
      `if(!src||!src.categoryComics||!src.categoryComics.ranking||!src.categoryComics.ranking.load)` +
      `return {comics:[],maxPage:1};` +
      `var res=await src.categoryComics.ranking.load(${safeOption},${page});` +
      `if(!res)return {comics:[],maxPage:1};` +
      `return {comics:res.comics||[],maxPage:res.maxPage||1};})()`;
  }

  buildComicInfoScript(sourceKey: string, comicId: string): string {
    const safeKey = JsEngineBridge.escapeJs(sourceKey);
    const safeComic = JsEngineBridge.escapeJs(comicId);
    return `(async function(){var src=ComicSource.sources[${safeKey}];` +
      `if(!src||!src.comic||!src.comic.loadInfo)return null;` +
      `return await src.comic.loadInfo(${safeComic});})()`;
  }

  buildComicPagesScript(sourceKey: string, comicId: string, chapterId: string): string {
    const safeKey = JsEngineBridge.escapeJs(sourceKey);
    const safeComic = JsEngineBridge.escapeJs(comicId);
    const safeChapter = JsEngineBridge.escapeJs(chapterId);
    return `(async function(){` +
      `var src=ComicSource.sources[${safeKey}];` +
      `if(!src||!src.comic||!src.comic.loadEp)return[];` +
      `var res=await src.comic.loadEp(${safeComic},${safeChapter});` +
      `if(!res||!res.images)return[];` +
      `function serImg(img,depth){` +
      `if(typeof img==='string')return img;` +
      `if(!img||typeof img!=='object')return null;` +
      `var o={url:img.url||'',method:img.method||'',data:img.data!=null?img.data:null};` +
      `if(img.headers)o.headers=img.headers;` +
      `if(typeof img.onResponse==='function')o.onResponse=img.onResponse.toString();` +
      `else if(typeof img.onResponse==='string')o.onResponse=img.onResponse;` +
      `if(typeof img.modifyImage==='string')o.modifyImage=img.modifyImage;` +
      `if(img.onLoadFailed&&depth<3)o.onLoadFailed=serImg(img.onLoadFailed,depth+1);` +
      `return o;` +
      `}` +
      `return res.images.map(function(x){return serImg(x,0);}).filter(function(x){return x!=null;});` +
      `})()`;
  }



  private static escapeJs(value: string): string {

    return JSON.stringify(value);

  }



  private parseComics(raw: Object | null): Comic[] {

    if (!raw || !Array.isArray(raw)) {

      return [];

    }

    const arr = raw as Array<Record<string, Object>>;

    const comics: Comic[] = [];

    for (let i = 0; i < arr.length; i++) {

      const item = arr[i];

      const c = new Comic();

      c.id = `${item['id'] ?? ''}`;

      c.title = `${item['title'] ?? ''}`;

      c.cover = `${item['cover'] ?? ''}`;

      c.description = `${item['description'] ?? ''}`;

      c.sourceKey = `${item['sourceKey'] ?? item['source'] ?? ''}`;

      if (c.sourceKey.length === 0 && item['key']) {

        c.sourceKey = `${item['key']}`;

      }

      comics.push(c);

    }

    return comics;

  }



  private parseChapters(raw: Object | null): ComicChapter[] {
    if (!raw || !Array.isArray(raw)) {
      return [];
    }
    const arr = raw as Array<Record<string, Object>>;
    const chapters: ComicChapter[] = [];
    for (let i = 0; i < arr.length; i++) {
      const item = arr[i];
      const ch = new ComicChapter();
      ch.id = `${item['id'] ?? ''}`;
      ch.title = `${item['title'] ?? item['name'] ?? ''}`;
      ch.subTitle = item['subTitle'] ? `${item['subTitle']}` : undefined;
      ch.cover = item['cover'] ? `${item['cover']}` : undefined;
      chapters.push(ch);
    }
    return chapters;
  }

  /** 解析 comic.loadInfo 返回的 chapters 对象（平铺或分组 Map） */
  private parseChaptersFromLoadInfo(raw: Object | null): ComicChapter[] {
    if (!raw || typeof raw !== 'object') {
      return [];
    }
    const chaptersObj = raw as Record<string, Object>;
    const out: ComicChapter[] = [];
    const keys = Object.keys(chaptersObj);
    for (let i = 0; i < keys.length; i++) {
      const key = keys[i];
      const value = chaptersObj[key];
      if (value !== null && typeof value === 'object' && !Array.isArray(value)) {
        const group = value as Record<string, Object>;
        const groupKeys = Object.keys(group);
        for (let j = 0; j < groupKeys.length; j++) {
          const epId = groupKeys[j];
          const ch = new ComicChapter();
          ch.id = epId;
          ch.title = `${group[epId]}`;
          ch.subTitle = key;
          out.push(ch);
        }
      } else {
        const ch = new ComicChapter();
        ch.id = key;
        ch.title = `${value}`;
        out.push(ch);
      }
    }
    return out;
  }



  private parseStringList(raw: Object | null): string[] {

    if (!raw || !Array.isArray(raw)) {

      return [];

    }

    const arr = raw as Array<Object>;

    const out: string[] = [];

    for (let i = 0; i < arr.length; i++) {

      out.push(`${arr[i]}`);

    }

    return out;

  }

  private parseCategoryItems(raw: Object | null): CategoryItem[] {
    if (!raw || !Array.isArray(raw)) {
      return [];
    }
    const arr = raw as Array<Record<string, Object>>;
    const out: CategoryItem[] = [];
    for (let i = 0; i < arr.length; i++) {
      const item = arr[i];
      const entry = new CategoryItem();
      entry.label = `${item['label'] ?? item['name'] ?? ''}`;
      entry.param = item['param'] !== undefined && item['param'] !== null ? `${item['param']}` : '';
      entry.partName = `${item['partName'] ?? ''}`;
      entry.itemType = `${item['itemType'] ?? 'category'}`;
      if (entry.label.length > 0) {
        out.push(entry);
      }
    }
    return out;
  }

  private parseCategoryComicsResult(raw: Object | null, sourceKey: string): CategoryComicsResult {
    const result = new CategoryComicsResult();
    if (!raw || typeof raw !== 'object') {
      return result;
    }
    const obj = raw as Record<string, Object>;
    result.maxPage = typeof obj['maxPage'] === 'number' ? obj['maxPage'] as number : 1;
    if (typeof obj['next'] === 'string') {
      result.next = obj['next'] as string;
    }
    result.comics = this.parseComics(obj['comics'] ?? null);
    for (let i = 0; i < result.comics.length; i++) {
      if (result.comics[i].sourceKey.length === 0) {
        result.comics[i].sourceKey = sourceKey;
      }
    }
    return result;
  }



  async evaluateRaw(script: string): Promise<void> {
    if (!this.runtimeReady) {
      return;
    }
    try {
      await JsNativeRuntime.evaluate(script);
    } catch (_e) {
      // ignore
    }
  }

  private async evaluateJson(script: string, tag: string): Promise<Object | null> {

    if (!this.runtimeReady) {

      return null;

    }

    try {

      const json = await JsNativeRuntime.evaluate(script);

      if (json.length === 0 || json === 'undefined') {

        return null;

      }

      return JSON.parse(json) as Object;

    } catch (e) {

      console.error(`[JsEngineBridge] ${tag} eval error: ${e}`);

      return null;

    }

  }



  async invokeExplore(sourceKey: string): Promise<ExploreSection[]> {
    if (!this.runtimeReady || !this.stagedSources.has(sourceKey)) {
      return [];
    }
    const script = this.buildExploreScript(sourceKey);
    const raw = await this.evaluateJson(script, 'invokeExplore');
    return this.parseExploreSections(raw, sourceKey);
  }

  async invokeListExplorePageTitles(): Promise<string[]> {
    if (!this.runtimeReady) {
      return [];
    }
    const raw = await this.evaluateJson(this.buildListExplorePageTitlesScript(), 'invokeListExplorePageTitles');
    return this.parseStringList(raw);
  }

  async invokeListExplorePageMeta(): Promise<ExplorePageMeta[]> {
    if (!this.runtimeReady) {
      return [];
    }
    const raw = await this.evaluateJson(this.buildListExplorePageMetaScript(), 'invokeListExplorePageMeta');
    if (!raw || !Array.isArray(raw)) {
      return [];
    }
    const arr = raw as Array<Record<string, Object>>;
    const out: ExplorePageMeta[] = [];
    for (let i = 0; i < arr.length; i++) {
      const m = new ExplorePageMeta();
      m.title = `${arr[i]['title'] ?? ''}`;
      m.sourceKey = `${arr[i]['sourceKey'] ?? ''}`;
      if (m.title.length > 0) {
        out.push(m);
      }
    }
    return out;
  }

  async invokeListCategoryPageMeta(): Promise<CategoryPageMeta[]> {
    if (!this.runtimeReady) {
      return [];
    }
    const raw = await this.evaluateJson(this.buildListCategoryPageMetaScript(), 'invokeListCategoryPageMeta');
    if (!raw || !Array.isArray(raw)) {
      return [];
    }
    const arr = raw as Array<Record<string, Object>>;
    const out: CategoryPageMeta[] = [];
    for (let i = 0; i < arr.length; i++) {
      const m = new CategoryPageMeta();
      m.key = `${arr[i]['key'] ?? ''}`;
      m.title = `${arr[i]['title'] ?? ''}`;
      m.sourceKey = `${arr[i]['sourceKey'] ?? ''}`;
      if (m.key.length > 0) {
        out.push(m);
      }
    }
    return out;
  }

  async invokeExploreByTitle(title: string, page: number = 1, nextCursor: string = ''): Promise<ExplorePageLoadResult | null> {
    if (!this.runtimeReady || title.length === 0) {
      return null;
    }
    const script = this.buildExploreByTitleScript(title, page, nextCursor);
    const raw = await this.evaluateJson(script, 'invokeExploreByTitle');
    return this.parseExplorePageLoadResult(raw);
  }

  private parseExplorePageLoadResult(raw: Object | null): ExplorePageLoadResult | null {
    if (!raw || typeof raw !== 'object') {
      return null;
    }
    const item = raw as Record<string, Object>;
    const result = new ExplorePageLoadResult();
    result.sourceKey = `${item['sourceKey'] ?? ''}`;
    result.exploreTitle = `${item['title'] ?? ''}`;
    result.maxPage = Number(item['maxPage'] ?? 1);
    result.page = Number(item['page'] ?? 1);
    result.nextCursor = `${item['nextCursor'] ?? ''}`;
    result.error = `${item['error'] ?? ''}`;
    result.sections = this.parseExploreSections(item['sections'] as Object | null, result.sourceKey);
    result.comics = this.parseComics(item['comics'] ?? null);
    result.mixedBlocks = this.parseExploreMixedBlocks(item['mixedBlocks'] as Object | null, result.sourceKey);
    for (let i = 0; i < result.comics.length; i++) {
      if (result.comics[i].sourceKey.length === 0) {
        result.comics[i].sourceKey = result.sourceKey;
      }
    }
    return result;
  }

  private parseExploreSections(raw: Object | null, sourceKey: string): ExploreSection[] {
    if (!raw || !Array.isArray(raw)) {
      return [];
    }
    const arr = raw as Array<Record<string, Object>>;
    const out: ExploreSection[] = [];
    for (let i = 0; i < arr.length; i++) {
      const item = arr[i];
      const section = new ExploreSection();
      section.title = `${item['title'] ?? ''}`;
      section.viewMoreJson = `${item['viewMoreJson'] ?? ''}`;
      section.comics = this.parseComics(item['comics'] ?? null);
      for (let j = 0; j < section.comics.length; j++) {
        if (section.comics[j].sourceKey.length === 0) {
          section.comics[j].sourceKey = sourceKey;
        }
      }
      if (section.comics.length > 0) {
        out.push(section);
      }
    }
    return out;
  }

  private parseExploreMixedBlocks(raw: Object | null, sourceKey: string): ExploreMixedBlock[] {
    if (!raw || !Array.isArray(raw)) {
      return [];
    }
    const arr = raw as Array<Record<string, Object>>;
    const out: ExploreMixedBlock[] = [];
    for (let i = 0; i < arr.length; i++) {
      const item = arr[i];
      const block = new ExploreMixedBlock();
      block.kind = `${item['kind'] ?? 'section'}`;
      block.title = `${item['title'] ?? ''}`;
      block.viewMoreJson = `${item['viewMoreJson'] ?? ''}`;
      block.comics = this.parseComics(item['comics'] ?? null);
      for (let j = 0; j < block.comics.length; j++) {
        if (block.comics[j].sourceKey.length === 0) {
          block.comics[j].sourceKey = sourceKey;
        }
      }
      if (block.comics.length > 0) {
        out.push(block);
      }
    }
    return out;
  }

  async invokeSearchableSourceKeys(): Promise<string[]> {
    if (!this.runtimeReady) {
      return [];
    }
    const raw = await this.evaluateJson(this.buildSearchableSourcesScript(), 'invokeSearchableSourceKeys');
    return this.parseStringList(raw);
  }

  async invokeListRankingPages(): Promise<RankingPageInfo[]> {
    if (!this.runtimeReady) {
      return [];
    }
    const raw = await this.evaluateJson(this.buildListRankingPagesScript(), 'invokeListRankingPages');
    if (!raw || !Array.isArray(raw)) {
      return [];
    }
    const arr = raw as Array<Record<string, Object>>;
    const out: RankingPageInfo[] = [];
    for (let i = 0; i < arr.length; i++) {
      const item = arr[i];
      const info = new RankingPageInfo();
      info.sourceKey = `${item['sourceKey'] ?? ''}`;
      info.categoryTitle = `${item['categoryTitle'] ?? ''}`;
      info.options = this.parseStringList(item['options'] ?? null);
      if (info.sourceKey.length > 0 && info.options.length > 0) {
        out.push(info);
      }
    }
    return out;
  }

  async invokeRankingComics(sourceKey: string, option: string, page: number): Promise<CategoryComicsResult> {
    if (!this.runtimeReady || !this.stagedSources.has(sourceKey)) {
      return new CategoryComicsResult();
    }
    const script = this.buildRankingComicsScript(sourceKey, option, page);
    const raw = await this.evaluateJson(script, 'invokeRankingComics');
    return this.parseCategoryComicsResult(raw, sourceKey);
  }

  async invokeSearch(sourceKey: string, keyword: string, options: string[] = [], page: number = 1): Promise<Comic[]> {
    const result = await this.invokeSearchPaged(sourceKey, keyword, options, page);
    return result.comics;
  }

  async invokeSearchPaged(sourceKey: string, keyword: string, options: string[], page: number): Promise<CategoryComicsResult> {
    if (!this.runtimeReady || !this.stagedSources.has(sourceKey)) {
      return new CategoryComicsResult();
    }
    const script = this.buildSearchScript(sourceKey, keyword, options, page);
    const raw = await this.evaluateJson(script, 'invokeSearchPaged');
    const result = this.parseCategoryComicsResult(raw, sourceKey);
    return result;
  }

  async invokeSourceSearchOptions(sourceKey: string): Promise<SearchOptionDef[]> {
    if (!this.runtimeReady || !this.stagedSources.has(sourceKey)) {
      return [];
    }
    const safeKey = JsEngineBridge.escapeJs(sourceKey);
    const script = `(function(){var s=ComicSource.sources[${safeKey}];` +
      `if(!s||!s.search||!s.search.optionList||!Array.isArray(s.search.optionList))return [];` +
      `var out=[];for(var i=0;i<s.search.optionList.length;i++){var el=s.search.optionList[i];` +
      `var opts=[];if(el.options){for(var j=0;j<el.options.length;j++){var o=el.options[j];` +
      `var val='';var txt='';if(typeof o==='string'){var dash=o.indexOf('-');` +
      `if(dash>0){val=o.substring(0,dash);txt=o.substring(dash+1);}else{val=o;txt=o;}}` +
      `else{val=o.value||'';txt=o.text||val;}opts.push({value:val,text:txt});}` +
      `var def=el.defaultValue!=null?String(el.defaultValue):(opts.length>0?opts[0].value:'');` +
      `out.push({label:el.label||'',type:el.type||'select',options:opts,defaultValue:def});}}return out;})()`;
    const raw = await this.evaluateJson(script, 'invokeSourceSearchOptions');
    if (!Array.isArray(raw)) {
      return [];
    }
    const arr = raw as Array<Record<string, Object>>;
    const defs: SearchOptionDef[] = [];
    for (let i = 0; i < arr.length; i++) {
      const item = arr[i];
      const def = new SearchOptionDef();
      def.label = `${item['label'] ?? ''}`;
      def.type = `${item['type'] ?? 'select'}`;
      def.defaultValue = `${item['defaultValue'] ?? ''}`;
      if (Array.isArray(item['options'])) {
        const opts = item['options'] as Array<Record<string, Object>>;
        for (let j = 0; j < opts.length; j++) {
          const o = new SourceSettingOption();
          o.value = `${opts[j]['value'] ?? ''}`;
          o.text = `${opts[j]['text'] ?? o.value}`;
          def.options.push(o);
        }
      }
      if (def.options.length > 0) {
        defs.push(def);
      }
    }
    return defs;
  }

  /** 图源 search.enableTagsSuggestions（默认 true） */
  async invokeSourceEnableTagSuggestions(sourceKey: string): Promise<boolean> {
    if (!this.runtimeReady || !this.stagedSources.has(sourceKey)) {
      return false;
    }
    const safeKey = JsEngineBridge.escapeJs(sourceKey);
    const script = `(function(){var s=ComicSource.sources[${safeKey}];` +
      `if(!s||!s.search)return false;` +
      `return s.search.enableTagsSuggestions!==false;})()`;
    const raw = await this.evaluateJson(script, 'invokeSourceEnableTagSuggestions');
    return raw === true;
  }

  /**
   * 搜索建议：comic.link / comic.idMatch — 对齐 upstream search_page findSuggestions
   */
  async invokeSearchSuggestionContext(text: string): Promise<SearchSuggestionContext> {
    const ctx = new SearchSuggestionContext();
    if (!this.runtimeReady || text.trim().length === 0) {
      return ctx;
    }
    const safeText = JsEngineBridge.escapeJs(text.trim());
    const script = `(function(t){var r={link:null,idKeys:[]};` +
      `var isUrl=/^https?:\\/\\//i.test(t);` +
      `for(var k in ComicSource.sources){var s=ComicSource.sources[k];if(!s||!s.comic)continue;` +
      `if(isUrl&&s.comic.link&&Array.isArray(s.comic.link.domains)&&typeof s.comic.link.linkToId==='function'){` +
      `try{var u=new URL(t);if(s.comic.link.domains.indexOf(u.host)>=0){` +
      `var id=s.comic.link.linkToId(t);if(id){r.link={sourceKey:k,id:String(id)};return r;}}catch(e){}}` +
      `if(s.comic.idMatch){try{if(new RegExp(s.comic.idMatch).test(t))r.idKeys.push(k);}catch(e){}}}` +
      `return r;})(${JSON.stringify(text.trim())})`;
    const raw = await this.evaluateJson(script, 'invokeSearchSuggestionContext');
    if (!raw || typeof raw !== 'object') {
      return ctx;
    }
    const obj = raw as Record<string, Object>;
    const link = obj['link'] as Record<string, Object> | null;
    if (link) {
      ctx.linkSourceKey = `${link['sourceKey'] ?? ''}`;
      ctx.linkComicId = `${link['id'] ?? ''}`;
    }
    if (Array.isArray(obj['idKeys'])) {
      const keys = obj['idKeys'] as string[];
      for (let i = 0; i < keys.length; i++) {
        const item = new SearchPageSourceItem();
        item.key = keys[i];
        const meta = await this.invokeSourceMeta(keys[i]);
        item.name = meta?.name ?? keys[i];
        ctx.idMatchSources.push(item);
      }
    }
    return ctx;
  }

  /** search.onTagSuggestionSelected — 无则返回 null */
  async invokeOnTagSuggestionSelected(sourceKey: string, namespace: string, tag: string): Promise<string | null> {
    if (!this.runtimeReady || !this.stagedSources.has(sourceKey)) {
      return null;
    }
    const safeKey = JsEngineBridge.escapeJs(sourceKey);
    const safeNs = JsEngineBridge.escapeJs(namespace);
    const safeTag = JsEngineBridge.escapeJs(tag);
    const script = `(function(){var s=ComicSource.sources[${safeKey}];` +
      `if(!s||!s.search||typeof s.search.onTagSuggestionSelected!=='function')return null;` +
      `var r=s.search.onTagSuggestionSelected(${safeNs},${safeTag});` +
      `return(typeof r==='string')?r:null;})()`;
    const raw = await this.evaluateJson(script, 'invokeOnTagSuggestionSelected');
    return typeof raw === 'string' ? raw : null;
  }

  async invokeCategories(sourceKey: string): Promise<CategoryItem[]> {

    if (!this.runtimeReady || !this.stagedSources.has(sourceKey)) {

      return [];

    }

    const script = this.buildCategoriesScript(sourceKey);

    return this.parseCategoryItems(await this.evaluateJson(script, 'invokeCategories'));

  }

  async invokeCategoryComics(sourceKey: string, item: CategoryItem, page: number): Promise<CategoryComicsResult> {
    if (!this.runtimeReady || !this.stagedSources.has(sourceKey)) {
      return new CategoryComicsResult();
    }
    const script = item.itemType === 'search' ?
      this.buildCategorySearchScript(sourceKey, item.label, page, []) :
      this.buildCategoryComicsScript(sourceKey, item.label, item.param, page);
    const raw = await this.evaluateJson(script, 'invokeCategoryComics');
    return this.parseCategoryComicsResult(raw, sourceKey);
  }



  async invokeComicPages(sourceKey: string, comicId: string, chapterId: string): Promise<string[]> {
    const entries = await this.invokeComicPageEntries(sourceKey, comicId, chapterId);
    const urls: string[] = [];
    for (let i = 0; i < entries.length; i++) {
      const item = entries[i];
      if (typeof item === 'string') {
        urls.push(item);
      } else if (item !== null && typeof item === 'object') {
        const cfg = item as Record<string, Object>;
        const u = cfg['url'];
        if (typeof u === 'string' && u.length > 0) {
          urls.push(u);
        }
      }
    }
    return urls;
  }

  /** comic.loadEp 原始页列表（字符串 URL 或 ImageLoadingConfig 对象） */
  async invokeComicPageEntries(sourceKey: string, comicId: string, chapterId: string): Promise<Object[]> {
    if (!this.runtimeReady || !this.stagedSources.has(sourceKey)) {
      return [];
    }
    const script = this.buildComicPagesScript(sourceKey, comicId, chapterId);
    const raw = await this.evaluateJson(script, 'invokeComicPageEntries');
    if (!raw || !Array.isArray(raw)) {
      return [];
    }
    return raw as Object[];
  }

  async invokeComicChapters(sourceKey: string, comicId: string): Promise<ComicChapter[]> {
    const info = await this.invokeComicInfo(sourceKey, comicId);
    return info.chapters;
  }

  /** comic.loadInfo 完整详情（章节、标签、评论、推荐） */
  async invokeComicInfo(sourceKey: string, comicId: string): Promise<ComicInfoResult> {
    const result = new ComicInfoResult();
    if (!this.runtimeReady || !this.stagedSources.has(sourceKey)) {
      return result;
    }
    const script = this.buildComicInfoScript(sourceKey, comicId);
    const raw = await this.evaluateJson(script, 'invokeComicInfo');
    if (!raw || typeof raw !== 'object') {
      return result;
    }
    const obj = raw as Record<string, Object>;
    result.comic = this.parseComicFromInfo(obj, sourceKey, comicId);
    const chaptersRaw = obj['chapters'];
    if (Array.isArray(chaptersRaw)) {
      result.chapters = this.parseChapters(chaptersRaw);
    } else {
      result.chapters = this.parseChaptersFromLoadInfo(chaptersRaw ?? null);
    }
    result.comments = this.parseComments(obj['comments'] ?? null);
    result.recommend = this.parseComics(obj['recommend'] ?? null);
    for (let i = 0; i < result.recommend.length; i++) {
      if (result.recommend[i].sourceKey.length === 0) {
        result.recommend[i].sourceKey = sourceKey;
      }
    }
    return result;
  }

  async invokeComicSupportsLike(sourceKey: string): Promise<boolean> {
    if (!this.runtimeReady || !this.stagedSources.has(sourceKey)) {
      return false;
    }
    const safeKey = JsEngineBridge.escapeJs(sourceKey);
    const script = `(function(){var s=ComicSource.sources[${safeKey}];` +
      `return !!(s&&s.comic&&typeof s.comic.likeComic==='function');})()`;
    const raw = await this.evaluateJson(script, 'invokeComicSupportsLike');
    return raw === true;
  }

  async invokeComicLike(sourceKey: string, comicId: string, isLiking: boolean): Promise<string> {
    if (!this.runtimeReady || !this.stagedSources.has(sourceKey)) {
      return '引擎未就绪';
    }
    const safeKey = JsEngineBridge.escapeJs(sourceKey);
    const safeId = JsEngineBridge.escapeJs(comicId);
    const script = `(async function(){var s=ComicSource.sources[${safeKey}];` +
      `if(!s||!s.comic||typeof s.comic.likeComic!=='function')return {error:'不支持点赞'};` +
      `try{await s.comic.likeComic(${safeId},${isLiking});return {ok:true};}` +
      `catch(e){return {error:String(e)};}})()`;
    const raw = await this.evaluateJson(script, 'invokeComicLike');
    if (!raw || typeof raw !== 'object') {
      return '点赞失败';
    }
    const obj = raw as Record<string, Object>;
    if (obj['ok'] === true) {
      return '';
    }
    return `${obj['error'] ?? '点赞失败'}`;
  }

  private parseComicFromInfo(obj: Record<string, Object>, sourceKey: string, comicId: string): Comic {
    const c = new Comic();
    c.id = comicId;
    c.sourceKey = sourceKey;
    c.title = `${obj['title'] ?? ''}`;
    c.cover = `${obj['cover'] ?? ''}`;
    c.description = `${obj['description'] ?? ''}`;
    if (obj['subtitle'] !== undefined) {
      c.subtitle = `${obj['subtitle']}`;
    }
    if (obj['subTitle'] !== undefined) {
      c.subtitle = `${obj['subTitle']}`;
    }
    if (Array.isArray(obj['tags'])) {
      const tagsArr = obj['tags'] as Array<Object>;
      c.tags = [];
      for (let i = 0; i < tagsArr.length; i++) {
        c.tags.push(`${tagsArr[i]}`);
      }
    } else if (obj['tags'] !== null && typeof obj['tags'] === 'object' && !Array.isArray(obj['tags'])) {
      const tagObj = obj['tags'] as Record<string, Object>;
      c.tagGroups = [];
      c.tags = [];
      const nsKeys = Object.keys(tagObj);
      for (let ni = 0; ni < nsKeys.length; ni++) {
        const ns = nsKeys[ni];
        const val = tagObj[ns];
        if (!Array.isArray(val)) {
          continue;
        }
        const group = new ComicTagGroup();
        group.namespace = ns;
        const arr = val as Array<Object>;
        for (let ti = 0; ti < arr.length; ti++) {
          const tag = `${arr[ti]}`;
          group.tags.push(tag);
          c.tags.push(`${ns}:${tag}`);
        }
        if (group.tags.length > 0) {
          c.tagGroups.push(group);
        }
      }
    }
    if (obj['url'] !== undefined) {
      c.url = `${obj['url']}`;
    }
    if (typeof obj['isLiked'] === 'boolean') {
      c.isLiked = obj['isLiked'] as boolean;
    }
    if (typeof obj['likesCount'] === 'number') {
      c.likesCount = obj['likesCount'] as number;
    }
    if (typeof obj['commentCount'] === 'number') {
      c.commentCount = obj['commentCount'] as number;
    }
    if (obj['uploader'] !== undefined) {
      c.uploader = `${obj['uploader']}`;
    }
    if (obj['uploadTime'] !== undefined) {
      c.uploadTime = `${obj['uploadTime']}`;
    }
    if (typeof obj['isFavorite'] === 'boolean') {
      c.isFavorite = obj['isFavorite'] as boolean;
    }
    if (typeof obj['maxPage'] === 'number') {
      c.maxPage = obj['maxPage'] as number;
    }
    if (typeof obj['stars'] === 'number') {
      c.stars = obj['stars'] as number;
    }
    if (obj['updateTime'] !== undefined) {
      c.updateTime = `${obj['updateTime']}`;
    }
    return c;
  }

  private parseComments(raw: Object | null): ComicComment[] {
    if (!raw || !Array.isArray(raw)) {
      return [];
    }
    const arr = raw as Array<Record<string, Object>>;
    const out: ComicComment[] = [];
    for (let i = 0; i < arr.length; i++) {
      const item = arr[i];
      const c = new ComicComment();
      c.id = `${item['id'] ?? ''}`;
      c.userName = `${item['userName'] ?? item['name'] ?? ''}`;
      c.avatar = `${item['avatar'] ?? ''}`;
      c.content = `${item['content'] ?? ''}`;
      c.time = `${item['time'] ?? ''}`;
      if (c.content.length > 0) {
        out.push(c);
      }
    }
    return out;
  }



  async loadSourceScript(sourceKey: string, scriptContent: string): Promise<boolean> {

    if (scriptContent.length === 0 || sourceKey.length === 0) {

      return false;

    }

    this.stagedSources.set(sourceKey, scriptContent);

    if (this.runtimeReady) {

      const ok = await JsNativeRuntime.loadSource(sourceKey, scriptContent);

      if (ok) {

        this.loadedNativeKeys.add(sourceKey);

        await this.invokeSourceInit(sourceKey);

      }

      return ok;

    }

    return this.initReady;

  }

  /** 将指定 key 的 staged 脚本编译进 QuickJS（跳过已加载项） */
  async registerSourcesToNative(sourceKeys: string[]): Promise<void> {

    if (!this.runtimeReady) {

      return;

    }

    for (let i = 0; i < sourceKeys.length; i++) {

      const key = sourceKeys[i];

      if (this.loadedNativeKeys.has(key)) {

        continue;

      }

      const script = this.stagedSources.get(key) ?? '';

      if (script.length === 0) {

        continue;

      }

      const ok = await JsNativeRuntime.loadSource(key, script);

      if (ok) {

        this.loadedNativeKeys.add(key);

        await this.invokeSourceInit(key);

      }

      if (i % 2 === 1) {

        await JsEngineBridge.yieldToUi();

      }

    }

  }

  private async registerAllStagedToNative(): Promise<void> {

    await this.registerSourcesToNative(this.getStagedSourceKeys());

  }

  /** 后台分批装入尚未注册到 QuickJS 的 staged 图源 */
  async registerPendingStagedInBackground(): Promise<void> {

    const pending: string[] = [];

    const keys = this.getStagedSourceKeys();

    for (let i = 0; i < keys.length; i++) {

      if (!this.loadedNativeKeys.has(keys[i])) {

        pending.push(keys[i]);

      }

    }

    if (pending.length === 0) {

      return;

    }

    console.info(`[JsEngineBridge] background native load ${pending.length} sources`);

    await this.registerSourcesToNative(pending);

  }



  readCachedSourceScript(sourceKey: string, sourcesPath?: string): string {

    const root = sourcesPath ?? this.sourcesPath;

    try {

      const path = `${root}/${sourceKey}.js`;

      const file = fileIo.openSync(path, fileIo.OpenMode.READ_ONLY);

      const stat = fileIo.statSync(path);

      const buf = new ArrayBuffer(stat.size);

      fileIo.readSync(file.fd, buf);

      fileIo.closeSync(file.fd);

      return JsEngineBridge.bytesToString(new Uint8Array(buf));

    } catch (_e) {

      return '';

    }

  }



  loadCachedSourcesFromDisk(): void {

    if (this.sourcesPath.length === 0) {

      return;

    }

    try {

      const names = fileIo.listFileSync(this.sourcesPath);

      for (const name of names) {

        if (!name.endsWith('.js')) {

          continue;

        }

        const key = name.substring(0, name.length - 3);

        const script = this.readCachedSourceScript(key, this.sourcesPath);

        if (script.length > 0) {

          this.stagedSources.set(key, script);

        }

      }

      console.info(`[JsEngineBridge] staged ${this.stagedSources.size} cached sources`);

    } catch (_e) {

      // empty dir

    }

  }

  /** 分批从沙箱读入 staged，避免长时间占用 UI 线程 */
  async loadCachedSourcesFromDiskAsync(): Promise<void> {

    if (this.sourcesPath.length === 0) {

      return;

    }

    try {

      const names = fileIo.listFileSync(this.sourcesPath);

      let read = 0;

      for (const name of names) {

        if (!name.endsWith('.js')) {

          continue;

        }

        const key = name.substring(0, name.length - 3);

        if (this.stagedSources.has(key)) {

          continue;

        }

        const script = this.readCachedSourceScript(key, this.sourcesPath);

        if (script.length > 0) {

          this.stagedSources.set(key, script);

        }

        read++;

        if (read % 3 === 0) {

          await JsEngineBridge.yieldToUi();

        }

      }

      console.info(`[JsEngineBridge] staged ${this.stagedSources.size} cached sources (async)`);

    } catch (_e) {

      // empty dir

    }

  }

  /** 批量安装图源后，将 staged 脚本重新注册到 QuickJS */
  async reloadStagedSourcesToNative(): Promise<void> {
    if (this.runtimeReady) {
      await this.registerAllStagedToNative();
    }
  }

  /** 重置 QuickJS 注册表并重新加载全部 staged 脚本 */
  async reloadAllSourcesToNative(): Promise<void> {
    if (!this.runtimeReady) {
      return;
    }
    JsNativeRuntime.resetSources();
    this.loadedNativeKeys.clear();
    await this.registerAllStagedToNative();
  }

  removeStagedSource(sourceKey: string): void {
    this.stagedSources.delete(sourceKey);
    this.loadedNativeKeys.delete(sourceKey);
    if (this.sourcesPath.length > 0) {
      try {
        fileIo.unlinkSync(`${this.sourcesPath}/${sourceKey}.js`);
      } catch (_e) {
        // ignore
      }
    }
  }

  private buildParseMetaScript(script: string): string {
    const className = SourceScriptUtil.extractClassName(script);
    if (className.length === 0) {
      return '';
    }
    const body = script.replace(/\r\n/g, '\n');
    return `(function(){${body}var t=new ${className}();return {key:t.key||'',name:t.name||'',` +
      `version:t.version||'',url:t.url||'',minAppVersion:t.minAppVersion||''};})()`;
  }

  async parseScriptMeta(script: string): Promise<InstalledComicSource | null> {
    const evalScript = this.buildParseMetaScript(script);
    if (this.runtimeReady && evalScript.length > 0) {
      const raw = await this.evaluateJson(evalScript, 'parseScriptMeta');
      if (raw && typeof raw === 'object') {
        const obj = raw as Record<string, Object>;
        const meta = new InstalledComicSource();
        meta.key = `${obj['key'] ?? ''}`;
        meta.name = `${obj['name'] ?? ''}`;
        meta.version = `${obj['version'] ?? ''}`;
        meta.url = `${obj['url'] ?? ''}`;
        const minApp = `${obj['minAppVersion'] ?? ''}`;
        if (meta.version.length === 0) {
          meta.version = '1.0.0';
        }
        if (meta.key.length > 0 && meta.name.length > 0) {
          if (minApp.length > 0) {
            meta.minAppVersion = minApp;
          }
          return meta;
        }
      }
    }
    const parsed = SourceScriptUtil.parseMetaFromScript(script);
    if (!parsed) {
      return null;
    }
    const fallback = new InstalledComicSource();
    fallback.key = parsed.key;
    fallback.name = parsed.name;
    fallback.version = parsed.version;
    fallback.url = parsed.url;
    fallback.minAppVersion = parsed.minAppVersion;
    return fallback;
  }

  private buildSourceMetaScript(sourceKey: string): string {
    const safeKey = JsEngineBridge.escapeJs(sourceKey);
    return `(function(){var s=ComicSource.sources[${safeKey}];if(!s)return null;` +
      `return {key:s.key||'',name:s.name||'',version:s.version||'',url:s.url||''};})()`;
  }

  async invokeSourceMeta(sourceKey: string): Promise<InstalledComicSource | null> {
    if (!this.runtimeReady || !this.stagedSources.has(sourceKey)) {
      return null;
    }
    const raw = await this.evaluateJson(this.buildSourceMetaScript(sourceKey), 'invokeSourceMeta');
    if (!raw || typeof raw !== 'object') {
      return null;
    }
    const obj = raw as Record<string, Object>;
    const meta = new InstalledComicSource();
    meta.key = `${obj['key'] ?? sourceKey}`;
    meta.name = `${obj['name'] ?? sourceKey}`;
    meta.version = `${obj['version'] ?? ''}`;
    meta.url = `${obj['url'] ?? ''}`;
    meta.filePath = `${this.sourcesPath}/${sourceKey}.js`;
    return meta;
  }

  async invokeAllInstalledMeta(): Promise<InstalledComicSource[]> {
    if (!this.runtimeReady) {
      return [];
    }
    const script = '(function(){var out=[];var srcs=ComicSource.sources;' +
      'for(var k in srcs){if(!Object.prototype.hasOwnProperty.call(srcs,k))continue;' +
      'var s=srcs[k];if(!s)continue;out.push({key:s.key||k,name:s.name||k,version:s.version||\'\',url:s.url||\'\'});}' +
      'return out;})()';
    const raw = await this.evaluateJson(script, 'invokeAllInstalledMeta');
    if (!Array.isArray(raw)) {
      return [];
    }
    const arr = raw as Array<Record<string, Object>>;
    const out: InstalledComicSource[] = [];
    for (let i = 0; i < arr.length; i++) {
      const obj = arr[i];
      if (!obj || typeof obj !== 'object') {
        continue;
      }
      const meta = new InstalledComicSource();
      meta.key = `${obj['key'] ?? ''}`;
      meta.name = `${obj['name'] ?? meta.key}`;
      meta.version = `${obj['version'] ?? ''}`;
      meta.url = `${obj['url'] ?? ''}`;
      if (meta.key.length > 0) {
        meta.filePath = `${this.sourcesPath}/${meta.key}.js`;
        out.push(meta);
      }
    }
    return out;
  }

  private buildSourceSettingsScript(sourceKey: string): string {
    const safeKey = JsEngineBridge.escapeJs(sourceKey);
    return `(function(){var s=ComicSource.sources[${safeKey}];if(!s)return null;` +
      `var st=s.settings;if(typeof st==='function'){try{st=st();}catch(e){return null;}}` +
      `if(!st||typeof st!=='object')return null;return st;})()`;
  }

  async invokeSourceSettings(sourceKey: string): Promise<SourceSettingDef[]> {
    const raw = await this.evaluateJson(this.buildSourceSettingsScript(sourceKey), 'invokeSourceSettings');
    if (!raw || typeof raw !== 'object') {
      return [];
    }
    const obj = raw as Record<string, Object>;
    const keys = Object.keys(obj);
    const defs: SourceSettingDef[] = [];
    for (let i = 0; i < keys.length; i++) {
      const sk = keys[i];
      const val = obj[sk];
      if (!val || typeof val !== 'object') {
        continue;
      }
      const item = val as Record<string, Object>;
      const def = new SourceSettingDef();
      def.key = sk;
      def.type = `${item['type'] ?? ''}`;
      def.title = `${item['title'] ?? sk}`;
      if (item['default'] !== undefined && item['default'] !== null) {
        if (typeof item['default'] === 'boolean') {
          def.defaultValue = item['default'] as boolean;
        } else {
          def.defaultValue = `${item['default']}`;
        }
      }
      def.validator = item['validator'] ? `${item['validator']}` : '';
      def.buttonText = item['buttonText'] ? `${item['buttonText']}` : '执行';
      if (Array.isArray(item['options'])) {
        const opts = item['options'] as Array<Record<string, Object>>;
        for (let j = 0; j < opts.length; j++) {
          const o = new SourceSettingOption();
          o.value = `${opts[j]['value'] ?? ''}`;
          o.text = `${opts[j]['text'] ?? o.value}`;
          def.options.push(o);
        }
      }
      defs.push(def);
    }
    return defs;
  }

  private buildSourceAccountScript(sourceKey: string): string {
    const safeKey = JsEngineBridge.escapeJs(sourceKey);
    return `(function(){var s=ComicSource.sources[${safeKey}];if(!s||!s.account)return null;` +
      `var a=s.account;return {loginWebsite:a.loginWebsite||'',registerWebsite:a.registerWebsite||'',` +
      `hasPasswordLogin:typeof a.login==='function',hasCookieLogin:typeof a.validateCookies==='function',` +
      `cookieFields:a.cookieFields||[]};})()`;
  }

  async invokeSourceAccount(sourceKey: string): Promise<SourceAccountConfig | null> {
    const raw = await this.evaluateJson(this.buildSourceAccountScript(sourceKey), 'invokeSourceAccount');
    if (!raw || typeof raw !== 'object') {
      return null;
    }
    const obj = raw as Record<string, Object>;
    const cfg = new SourceAccountConfig();
    cfg.loginWebsite = `${obj['loginWebsite'] ?? ''}`;
    cfg.registerWebsite = `${obj['registerWebsite'] ?? ''}`;
    cfg.hasPasswordLogin = obj['hasPasswordLogin'] === true;
    cfg.hasCookieLogin = obj['hasCookieLogin'] === true;
    if (Array.isArray(obj['cookieFields'])) {
      const arr = obj['cookieFields'] as Array<Object>;
      for (let i = 0; i < arr.length; i++) {
        cfg.cookieFields.push(`${arr[i]}`);
      }
    }
    return cfg;
  }

  async invokeAccountLogin(sourceKey: string, username: string, password: string): Promise<string> {
    const safeKey = JsEngineBridge.escapeJs(sourceKey);
    const safeUser = JsEngineBridge.escapeJs(username);
    const safePass = JsEngineBridge.escapeJs(password);
    const script = `(async function(){try{var s=ComicSource.sources[${safeKey}];` +
      `if(!s)return {error:'漫画源未装入，请返回稍后重试'};` +
      `if(!s.account||typeof s.account.login!=='function')return {error:'未配置密码登录'};` +
      `var r=await s.account.login(${safeUser},${safePass});` +
      `if(!r)return {error:'登录失败'};` +
      `if(r.error||r.errorMessage)return {error:r.errorMessage||r.error||'登录失败'};` +
      `return {ok:true};}catch(e){return {error:String(e)};}})()`;
    const raw = await this.evaluateJson(script, 'invokeAccountLogin');
    if (!raw || typeof raw !== 'object') {
      return '登录失败';
    }
    const obj = raw as Record<string, Object>;
    if (obj['ok'] === true) {
      return '';
    }
    return `${obj['error'] ?? '登录失败'}`;
  }

  private buildSourcePageKeysScript(sourceKey: string): string {
    const safeKey = JsEngineBridge.escapeJs(sourceKey);
    return `(function(){var s=ComicSource.sources[${safeKey}];if(!s)return {explore:[],category:'',favorite:'',search:false};` +
      `var explore=[];if(s.explore){for(var i=0;i<s.explore.length;i++){if(s.explore[i]&&s.explore[i].title)explore.push(s.explore[i].title);}}` +
      `var cat=(s.category&&s.category.key)?s.category.key:'';` +
      `var fav=(s.favorite&&s.favorite.key)?s.favorite.key:'';` +
      `var search=!!(s.search&&typeof s.search.load==='function');` +
      `return {explore:explore,category:cat,favorite:fav,search:search};})()`;
  }

  async invokeSourcePageKeys(sourceKey: string): Promise<Object | null> {
    return await this.evaluateJson(this.buildSourcePageKeysScript(sourceKey), 'invokeSourcePageKeys');
  }

  async invokeSettingCallback(sourceKey: string, settingKey: string): Promise<string> {
    const safeKey = JsEngineBridge.escapeJs(sourceKey);
    const safeSetting = JsEngineBridge.escapeJs(settingKey);
    const script = `(async function(){var s=ComicSource.sources[${safeKey}];if(!s)return {error:'源不存在'};` +
      `var st=s.settings;if(typeof st==='function'){try{st=st();}catch(e){return {error:'settings 读取失败'};}}` +
      `if(!st||!st[${safeSetting}]||st[${safeSetting}].type!=='callback')return {error:'无效设置'};` +
      `var cb=st[${safeSetting}].callback;if(typeof cb!=='function')return {error:'无回调'};` +
      `try{var r=cb([]);if(r&&typeof r.then==='function')await r;}catch(e){return {error:String(e)};}` +
      `return {ok:true};})()`;
    const raw = await this.evaluateJson(script, 'invokeSettingCallback');
    if (!raw || typeof raw !== 'object') {
      return '';
    }
    const obj = raw as Record<string, Object>;
    if (obj['ok'] === true) {
      return '';
    }
    return `${obj['error'] ?? ''}`;
  }

  /** 图源 translation 对象 — 对齐上游 .ts(sourceKey) */
  async invokeSourceTranslate(sourceKey: string, text: string): Promise<string> {
    if (text.length === 0) {
      return text;
    }
    const safeKey = JsEngineBridge.escapeJs(sourceKey);
    const safeText = JsEngineBridge.escapeJs(text);
    const script = `(function(){var s=ComicSource.sources[${safeKey}];` +
      `if(!s||typeof s.translate!=='function')return ${safeText};` +
      `try{return s.translate(${safeText});}catch(e){return ${safeText};}})()`;
    const raw = await this.evaluateJson(script, 'invokeSourceTranslate');
    if (typeof raw === 'string') {
      return raw;
    }
    return text;
  }

  /** 装入后调用图源 init() — 对齐上游 ComicSourceParser.parse 延迟 init */
  async invokeSourceInit(sourceKey: string): Promise<void> {
    if (!this.runtimeReady || sourceKey.length === 0) {
      return;
    }
    const safeKey = JsEngineBridge.escapeJs(sourceKey);
    const script = `(function(){try{var s=ComicSource.sources[${safeKey}];` +
      `if(s&&typeof s.init==='function')s.init();}catch(e){}})()`;
    await this.evaluateRaw(script);
  }

  /** WebView 登录状态检测 — 对齐 account.loginWithWebview.checkStatus */
  async invokeWebviewCheckStatus(sourceKey: string, pageUrl: string, pageTitle: string): Promise<boolean> {
    const safeKey = JsEngineBridge.escapeJs(sourceKey);
    const safeUrl = JsEngineBridge.escapeJs(pageUrl);
    const safeTitle = JsEngineBridge.escapeJs(pageTitle);
    const script = `(function(){try{var s=ComicSource.sources[${safeKey}];` +
      `if(!s||!s.account||!s.account.loginWithWebview||` +
      `typeof s.account.loginWithWebview.checkStatus!=='function')return false;` +
      `return !!s.account.loginWithWebview.checkStatus(${safeUrl},${safeTitle});` +
      `}catch(e){return false;}})()`;
    const raw = await this.evaluateJson(script, 'invokeWebviewCheckStatus');
    return raw === true;
  }

  /** WebView 登录成功回调 — 对齐 account.loginWithWebview.onLoginSuccess */
  async invokeWebviewLoginSuccess(sourceKey: string): Promise<void> {
    const safeKey = JsEngineBridge.escapeJs(sourceKey);
    const script = `(function(){try{var s=ComicSource.sources[${safeKey}];` +
      `if(s&&s.account&&s.account.loginWithWebview&&` +
      `typeof s.account.loginWithWebview.onLoginSuccess==='function')` +
      `s.account.loginWithWebview.onLoginSuccess();}catch(e){}})()`;
    await this.evaluateRaw(script);
  }

  /** Cookie 登录校验 — 对齐 account.loginWithCookies.validate */
  async invokeValidateCookies(sourceKey: string, cookieValues: string[]): Promise<boolean> {
    const safeKey = JsEngineBridge.escapeJs(sourceKey);
    const safeCookies = JSON.stringify(cookieValues);
    const script = `(async function(){try{var s=ComicSource.sources[${safeKey}];` +
      `if(!s||!s.account||!s.account.loginWithCookies||` +
      `typeof s.account.loginWithCookies.validate!=='function')return false;` +
      `return !!(await s.account.loginWithCookies.validate(${safeCookies}));` +
      `}catch(e){return false;}})()`;
    const raw = await this.evaluateJson(script, 'invokeValidateCookies');
    return raw === true;
  }

  /** 图源 account.reLogin — 对齐上游重新登录 */
  async invokeAccountReLogin(sourceKey: string): Promise<string> {
    const safeKey = JsEngineBridge.escapeJs(sourceKey);
    const script = `(async function(){var s=ComicSource.sources[${safeKey}];` +
      `if(!s||!s.account||typeof s.account.reLogin!=='function')return {error:'不支持重新登录'};` +
      `try{await s.account.reLogin();return {ok:true};}catch(e){return {error:String(e)};}})()`;
    const raw = await this.evaluateJson(script, 'invokeAccountReLogin');
    if (!raw || typeof raw !== 'object') {
      return '重新登录失败';
    }
    const obj = raw as Record<string, Object>;
    if (obj['ok'] === true) {
      return '';
    }
    return `${obj['error'] ?? '重新登录失败'}`;
  }

  buildFavoriteMetaScript(sourceKey: string): string {
    const safeKey = JsEngineBridge.escapeJs(sourceKey);
    return `(function(){var s=ComicSource.sources[${safeKey}];if(!s||!s.favorites)return null;` +
      `var fav=s.favorite||{};return {favoriteKey:(fav.key||${safeKey}),title:(fav.title||s.name||${safeKey}),` +
      `multiFolder:!!s.favorites.multiFolder,hasLoadComics:typeof s.favorites.loadComics==='function',` +
      `hasLoadNext:typeof s.favorites.loadNext==='function',hasAddOrDel:typeof s.favorites.addOrDelFavorite==='function'};})()`;
  }

  buildFavoriteLoadComicsScript(sourceKey: string, page: number, folderId: string | null): string {
    const safeKey = JsEngineBridge.escapeJs(sourceKey);
    const folderJs = folderId !== null && folderId.length > 0 ?
      JsEngineBridge.escapeJs(folderId) : 'null';
    return `(async function(){var s=ComicSource.sources[${safeKey}];` +
      `if(!s||!s.favorites||!s.favorites.loadComics)return {error:'不支持',comics:[],maxPage:1};` +
      `try{var res=await s.favorites.loadComics(${page},${folderJs});` +
      `if(!res)return {comics:[],maxPage:1};return {comics:res.comics||[],maxPage:res.maxPage||1,next:res.next||''};` +
      `}catch(e){return {error:String(e),comics:[],maxPage:1};}})()`;
  }

  buildFavoriteLoadNextScript(sourceKey: string, next: string, folderId: string | null): string {
    const safeKey = JsEngineBridge.escapeJs(sourceKey);
    const safeNext = JsEngineBridge.escapeJs(next);
    const folderJs = folderId !== null && folderId.length > 0 ?
      JsEngineBridge.escapeJs(folderId) : 'null';
    return `(async function(){var s=ComicSource.sources[${safeKey}];` +
      `if(!s||!s.favorites||!s.favorites.loadNext)return {error:'不支持',comics:[]};` +
      `try{var res=await s.favorites.loadNext(${safeNext},${folderJs});` +
      `if(!res)return {comics:[]};return {comics:res.comics||[],next:res.next||''};` +
      `}catch(e){return {error:String(e),comics:[]};}})()`;
  }

  buildFavoriteLoadFoldersScript(sourceKey: string, comicId: string | null): string {
    const safeKey = JsEngineBridge.escapeJs(sourceKey);
    const comicJs = comicId !== null && comicId.length > 0 ?
      JsEngineBridge.escapeJs(comicId) : 'null';
    return `(async function(){var s=ComicSource.sources[${safeKey}];` +
      `if(!s||!s.favorites||!s.favorites.loadFolders)return {error:'不支持',folders:{}};` +
      `try{var res=await s.favorites.loadFolders(${comicJs});` +
      `if(!res)return {folders:{},added:[]};var added=[];` +
      `if(res.added&&Array.isArray(res.added))added=res.added;` +
      `else if(res.subData&&Array.isArray(res.subData))added=res.subData;` +
      `return {folders:res.folders||{},added:added};` +
      `}catch(e){return {error:String(e),folders:{},added:[]};}})()`;
  }

  buildFavoriteAddOrDelScript(
    sourceKey: string,
    comicId: string,
    folderId: string,
    isAdding: boolean
  ): string {
    const safeKey = JsEngineBridge.escapeJs(sourceKey);
    const safeComic = JsEngineBridge.escapeJs(comicId);
    const safeFolder = JsEngineBridge.escapeJs(folderId);
    return `(async function(){var s=ComicSource.sources[${safeKey}];` +
      `if(!s||!s.favorites||!s.favorites.addOrDelFavorite)return {error:'不支持'};` +
      `try{await s.favorites.addOrDelFavorite(${safeComic},${safeFolder},${isAdding});` +
      `return {ok:true};}catch(e){return {error:String(e)};}})()`;
  }

  buildListFavoriteSourceKeysScript(): string {
    return `(function(){var out=[];var keys=Object.keys(ComicSource.sources);` +
      `for(var i=0;i<keys.length;i++){var s=ComicSource.sources[keys[i]];` +
      `if(s&&s.favorites&&(typeof s.favorites.loadComics==='function'||` +
      `typeof s.favorites.loadFolders==='function'))out.push(keys[i]);}return out;})()`;
  }

  async invokeFavoriteMeta(sourceKey: string): Promise<NetworkFavoriteMeta | null> {
    if (!this.runtimeReady || !this.stagedSources.has(sourceKey)) {
      return null;
    }
    const raw = await this.evaluateJson(this.buildFavoriteMetaScript(sourceKey), 'invokeFavoriteMeta');
    if (!raw || typeof raw !== 'object') {
      return null;
    }
    const obj = raw as Record<string, Object>;
    const meta = new NetworkFavoriteMeta();
    meta.sourceKey = sourceKey;
    meta.favoriteKey = `${obj['favoriteKey'] ?? sourceKey}`;
    meta.title = `${obj['title'] ?? sourceKey}`;
    meta.multiFolder = obj['multiFolder'] === true;
    meta.hasLoadComics = obj['hasLoadComics'] === true;
    meta.hasLoadNext = obj['hasLoadNext'] === true;
    meta.hasAddOrDel = obj['hasAddOrDel'] === true;
    return meta;
  }

  async invokeFavoriteLoadComics(
    sourceKey: string,
    page: number,
    folderId: string | null
  ): Promise<CategoryComicsResult> {
    if (!this.runtimeReady || !this.stagedSources.has(sourceKey)) {
      const empty = new CategoryComicsResult();
      empty.error = '引擎未就绪';
      return empty;
    }
    const raw = await this.evaluateJson(
      this.buildFavoriteLoadComicsScript(sourceKey, page, folderId),
      'invokeFavoriteLoadComics'
    );
    const result = this.parseCategoryComicsResult(raw, sourceKey);
    if (raw && typeof raw === 'object') {
      const obj = raw as Record<string, Object>;
      if (typeof obj['error'] === 'string') {
        result.error = obj['error'] as string;
      }
    }
    return result;
  }

  async invokeFavoriteLoadNext(
    sourceKey: string,
    next: string,
    folderId: string | null
  ): Promise<CategoryComicsResult> {
    if (!this.runtimeReady || !this.stagedSources.has(sourceKey)) {
      const empty = new CategoryComicsResult();
      empty.error = '引擎未就绪';
      return empty;
    }
    const raw = await this.evaluateJson(
      this.buildFavoriteLoadNextScript(sourceKey, next, folderId),
      'invokeFavoriteLoadNext'
    );
    const result = this.parseCategoryComicsResult(raw, sourceKey);
    if (raw && typeof raw === 'object') {
      const obj = raw as Record<string, Object>;
      if (typeof obj['error'] === 'string') {
        result.error = obj['error'] as string;
      }
      if (typeof obj['next'] === 'string') {
        result.next = obj['next'] as string;
      }
    }
    return result;
  }

  async invokeFavoriteLoadFolders(sourceKey: string, comicId: string | null): Promise<FavoriteFoldersResult> {
    const result = new FavoriteFoldersResult();
    if (!this.runtimeReady || !this.stagedSources.has(sourceKey)) {
      result.error = '引擎未就绪';
      return result;
    }
    const raw = await this.evaluateJson(
      this.buildFavoriteLoadFoldersScript(sourceKey, comicId),
      'invokeFavoriteLoadFolders'
    );
    if (!raw || typeof raw !== 'object') {
      return result;
    }
    const obj = raw as Record<string, Object>;
    if (typeof obj['error'] === 'string') {
      result.error = obj['error'] as string;
    }
    const foldersRaw = obj['folders'];
    if (foldersRaw && typeof foldersRaw === 'object') {
      const map = foldersRaw as Record<string, Object>;
      const keys = Object.keys(map);
      for (let i = 0; i < keys.length; i++) {
        result.folders[keys[i]] = `${map[keys[i]]}`;
      }
    }
    if (Array.isArray(obj['added'])) {
      const addedArr = obj['added'] as Array<Object>;
      for (let i = 0; i < addedArr.length; i++) {
        result.addedFolderIds.push(`${addedArr[i]}`);
      }
    }
    return result;
  }

  async invokeFavoriteAddOrDel(
    sourceKey: string,
    comicId: string,
    folderId: string,
    isAdding: boolean
  ): Promise<string> {
    if (!this.runtimeReady || !this.stagedSources.has(sourceKey)) {
      return '引擎未就绪';
    }
    const raw = await this.evaluateJson(
      this.buildFavoriteAddOrDelScript(sourceKey, comicId, folderId, isAdding),
      'invokeFavoriteAddOrDel'
    );
    if (!raw || typeof raw !== 'object') {
      return '操作失败';
    }
    const obj = raw as Record<string, Object>;
    if (obj['ok'] === true) {
      return '';
    }
    return `${obj['error'] ?? '操作失败'}`;
  }

  async invokeListFavoriteSourceKeys(): Promise<string[]> {
    if (!this.runtimeReady) {
      return [];
    }
    const raw = await this.evaluateJson(this.buildListFavoriteSourceKeysScript(), 'invokeListFavoriteSourceKeys');
    if (!raw || !Array.isArray(raw)) {
      return [];
    }
    return raw as string[];
  }

}

