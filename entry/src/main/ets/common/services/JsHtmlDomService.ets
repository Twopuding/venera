/**
 * init.js HtmlDocument / HtmlElement 宿主（对齐 upstream js_engine.dart DocumentWrapper）。
 * 纯 ArkTS 实现，供 QuickJS sendMessage 同步路径调用（API 23）。
 */

type HtmlNodeType = 'element' | 'text' | 'comment' | 'document';

interface HtmlTreeNode {
  nodeType: HtmlNodeType;
  tagName: string;
  attributes: Record<string, string>;
  children: HtmlTreeNode[];
  text: string;
  parent: HtmlTreeNode | null;
}

class HtmlDocumentWrapper {
  private readonly root: HtmlTreeNode;
  private elements: HtmlTreeNode[] = [];
  private nodes: HtmlTreeNode[] = [];

  constructor(html: string) {
    this.root = HtmlParser.parse(html);
    this.root.nodeType = 'document';
  }

  private registerElement(el: HtmlTreeNode): number {
    this.elements.push(el);
    return this.elements.length - 1;
  }

  private registerNode(node: HtmlTreeNode): number {
    this.nodes.push(node);
    return this.nodes.length - 1;
  }

  private elementAt(key: number): HtmlTreeNode | null {
    if (key < 0 || key >= this.elements.length) {
      return null;
    }
    return this.elements[key];
  }

  querySelector(query: string): number | null {
    const found = CssQuery.findFirst(this.root, query);
    if (!found || found.nodeType !== 'element') {
      return null;
    }
    return this.registerElement(found);
  }

  querySelectorAll(query: string): number[] {
    const found = CssQuery.findAll(this.root, query);
    const keys: number[] = [];
    for (let i = 0; i < found.length; i++) {
      if (found[i].nodeType === 'element') {
        keys.push(this.registerElement(found[i]));
      }
    }
    return keys;
  }

  getElementById(id: string): number | null {
    return this.querySelector(`#${CssQuery.escapeId(id)}`);
  }

  elementGetText(key: number): string | null {
    const el = this.elementAt(key);
    if (!el) {
      return null;
    }
    return HtmlDomUtil.collectText(el);
  }

  elementGetAttributes(key: number): Record<string, string> | null {
    const el = this.elementAt(key);
    if (!el) {
      return null;
    }
    return HtmlDomUtil.copyAttributes(el.attributes);
  }

  elementGetInnerHTML(key: number): string | null {
    const el = this.elementAt(key);
    if (!el) {
      return null;
    }
    return HtmlDomUtil.serializeInner(el);
  }

  elementGetParent(key: number): number | null {
    const el = this.elementAt(key);
    if (!el || !el.parent || el.parent.nodeType !== 'element') {
      return null;
    }
    return this.registerElement(el.parent);
  }

  elementQuerySelector(key: number, query: string): number | null {
    const el = this.elementAt(key);
    if (!el) {
      return null;
    }
    const found = CssQuery.findFirst(el, query);
    if (!found || found.nodeType !== 'element') {
      return null;
    }
    return this.registerElement(found);
  }

  elementQuerySelectorAll(key: number, query: string): number[] {
    const el = this.elementAt(key);
    if (!el) {
      return [];
    }
    const found = CssQuery.findAll(el, query);
    const keys: number[] = [];
    for (let i = 0; i < found.length; i++) {
      if (found[i].nodeType === 'element') {
        keys.push(this.registerElement(found[i]));
      }
    }
    return keys;
  }

  elementGetChildren(key: number): number[] {
    const el = this.elementAt(key);
    if (!el) {
      return [];
    }
    const keys: number[] = [];
    for (let i = 0; i < el.children.length; i++) {
      const child = el.children[i];
      if (child.nodeType === 'element') {
        keys.push(this.registerElement(child));
      }
    }
    return keys;
  }

  elementGetNodes(key: number): number[] {
    const el = this.elementAt(key);
    if (!el) {
      return [];
    }
    const keys: number[] = [];
    for (let i = 0; i < el.children.length; i++) {
      keys.push(this.registerNode(el.children[i]));
    }
    return keys;
  }

  nodeGetText(key: number): string | null {
    if (key < 0 || key >= this.nodes.length) {
      return null;
    }
    const node = this.nodes[key];
    if (node.nodeType === 'text') {
      return node.text;
    }
    return HtmlDomUtil.collectText(node);
  }

  nodeType(key: number): string {
    if (key < 0 || key >= this.nodes.length) {
      return 'unknown';
    }
    return this.nodes[key].nodeType;
  }

  nodeToElement(key: number): number | null {
    if (key < 0 || key >= this.nodes.length) {
      return null;
    }
    const node = this.nodes[key];
    if (node.nodeType !== 'element') {
      return null;
    }
    return this.registerElement(node);
  }

  getClassNames(key: number): string[] {
    const el = this.elementAt(key);
    if (!el) {
      return [];
    }
    const cls = el.attributes['class'] ?? '';
    return cls.split(/\s+/).filter((c: string) => c.length > 0);
  }

  getId(key: number): string | null {
    const el = this.elementAt(key);
    if (!el) {
      return null;
    }
    return el.attributes['id'] ?? null;
  }

  getLocalName(key: number): string | null {
    const el = this.elementAt(key);
    if (!el) {
      return null;
    }
    return el.tagName;
  }

  getPreviousSibling(key: number): number | null {
    const el = this.elementAt(key);
    if (!el || !el.parent) {
      return null;
    }
    const siblings = el.parent.children;
    let idx = -1;
    for (let i = 0; i < siblings.length; i++) {
      if (siblings[i] === el) {
        idx = i;
        break;
      }
    }
    for (let i = idx - 1; i >= 0; i--) {
      if (siblings[i].nodeType === 'element') {
        return this.registerElement(siblings[i]);
      }
    }
    return null;
  }

  getNextSibling(key: number): number | null {
    const el = this.elementAt(key);
    if (!el || !el.parent) {
      return null;
    }
    const siblings = el.parent.children;
    let idx = -1;
    for (let i = 0; i < siblings.length; i++) {
      if (siblings[i] === el) {
        idx = i;
        break;
      }
    }
    for (let i = idx + 1; i < siblings.length; i++) {
      if (siblings[i].nodeType === 'element') {
        return this.registerElement(siblings[i]);
      }
    }
    return null;
  }
}

class HtmlDomUtil {
  static collectText(node: HtmlTreeNode): string {
    if (node.nodeType === 'text') {
      return node.text;
    }
    let out = '';
    for (let i = 0; i < node.children.length; i++) {
      out += HtmlDomUtil.collectText(node.children[i]);
    }
    return out;
  }

  static copyAttributes(attrs: Record<string, string>): Record<string, string> {
    const out: Record<string, string> = {};
    const keys = Object.keys(attrs);
    for (let i = 0; i < keys.length; i++) {
      out[keys[i]] = attrs[keys[i]];
    }
    return out;
  }

  static serializeInner(el: HtmlTreeNode): string {
    let html = '';
    for (let i = 0; i < el.children.length; i++) {
      html += HtmlDomUtil.serializeNode(el.children[i]);
    }
    return html;
  }

  static serializeNode(node: HtmlTreeNode): string {
    if (node.nodeType === 'text') {
      return node.text;
    }
    if (node.nodeType !== 'element') {
      return '';
    }
    const voidTags = new Set(['br', 'hr', 'img', 'input', 'meta', 'link', 'source', 'area', 'base', 'col', 'embed', 'param', 'track', 'wbr']);
    let attrs = '';
    const keys = Object.keys(node.attributes);
    for (let i = 0; i < keys.length; i++) {
      const k = keys[i];
      attrs += ` ${k}="${HtmlDomUtil.escapeAttr(node.attributes[k])}"`;
    }
    if (voidTags.has(node.tagName)) {
      return `<${node.tagName}${attrs}>`;
    }
    let inner = '';
    for (let i = 0; i < node.children.length; i++) {
      inner += HtmlDomUtil.serializeNode(node.children[i]);
    }
    return `<${node.tagName}${attrs}>${inner}</${node.tagName}>`;
  }

  static escapeAttr(value: string): string {
    return value.replace(/&/g, '&amp;').replace(/"/g, '&quot;').replace(/</g, '&lt;');
  }

  static decodeEntities(text: string): string {
    return text
      .replace(/&lt;/g, '<')
      .replace(/&gt;/g, '>')
      .replace(/&amp;/g, '&')
      .replace(/&quot;/g, '"')
      .replace(/&#39;/g, "'")
      .replace(/&nbsp;/g, ' ');
  }
}

class HtmlParser {
  private static readonly VOID_TAGS =
    new Set(['area', 'base', 'br', 'col', 'embed', 'hr', 'img', 'input', 'link', 'meta', 'param', 'source', 'track', 'wbr']);

  static parse(html: string): HtmlTreeNode {
    const root: HtmlTreeNode = {
      nodeType: 'element',
      tagName: 'html',
      attributes: {},
      children: [],
      text: '',
      parent: null
    };
    const stack: HtmlTreeNode[] = [root];
    let i = 0;
    const len = html.length;
    while (i < len) {
      if (html.charAt(i) === '<') {
        if (html.startsWith('<!--', i)) {
          const end = html.indexOf('-->', i + 4);
          i = end >= 0 ? end + 3 : len;
          continue;
        }
        if (html.startsWith('<!', i) || html.startsWith('<?', i)) {
          const end = html.indexOf('>', i);
          i = end >= 0 ? end + 1 : len;
          continue;
        }
        if (html.charAt(i + 1) === '/') {
          const closeEnd = html.indexOf('>', i);
          if (closeEnd < 0) {
            break;
          }
          const closeTag = html.substring(i + 2, closeEnd).trim().split(/\s+/)[0].toLowerCase();
          if (stack.length > 1) {
            const top = stack[stack.length - 1];
            if (top.tagName === closeTag) {
              stack.pop();
            } else {
              for (let s = stack.length - 1; s > 0; s--) {
                if (stack[s].tagName === closeTag) {
                  stack.length = s;
                  break;
                }
              }
            }
          }
          i = closeEnd + 1;
          continue;
        }
        const tagEnd = html.indexOf('>', i);
        if (tagEnd < 0) {
          break;
        }
        const tagContent = html.substring(i + 1, tagEnd).trim();
        const selfClose = tagContent.endsWith('/');
        const parts = tagContent.replace(/\/$/, '').trim().split(/\s+/);
        const tagName = (parts[0] ?? '').toLowerCase();
        const attrs = HtmlParser.parseAttributes(tagContent.substring(parts[0].length));
        const el: HtmlTreeNode = {
          nodeType: 'element',
          tagName: tagName,
          attributes: attrs,
          children: [],
          text: '',
          parent: stack[stack.length - 1]
        };
        stack[stack.length - 1].children.push(el);
        if (!selfClose && !HtmlParser.VOID_TAGS.has(tagName)) {
          stack.push(el);
        }
        i = tagEnd + 1;
        continue;
      }
      const nextTag = html.indexOf('<', i);
      const rawText = nextTag >= 0 ? html.substring(i, nextTag) : html.substring(i);
      const text = HtmlDomUtil.decodeEntities(rawText);
      if (text.trim().length > 0 || text.length > 0) {
        const textNode: HtmlTreeNode = {
          nodeType: 'text',
          tagName: '#text',
          attributes: {},
          children: [],
          text: text,
          parent: stack[stack.length - 1]
        };
        stack[stack.length - 1].children.push(textNode);
      }
      i = nextTag >= 0 ? nextTag : len;
    }
    return root;
  }

  private static parseAttributes(tagContent: string): Record<string, string> {
    const attrs: Record<string, string> = {};
    const re = /([^\s=]+)(?:\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'>]+)))?/g;
    let m: RegExpExecArray | null = re.exec(tagContent);
    while (m !== null) {
      const name = m[1].toLowerCase();
      if (name.length > 0 && name !== '/' && !name.startsWith('/')) {
        attrs[name] = m[2] ?? m[3] ?? m[4] ?? '';
      }
      m = re.exec(tagContent);
    }
    return attrs;
  }
}

interface CssAttrRule {
  name: string;
  op: string;
  value: string;
}

interface CssSimpleSelector {
  tag: string | null;
  id: string | null;
  classes: string[];
  attrs: CssAttrRule[];
}

interface CssSelectorChain {
  parts: CssSimpleSelector[];
  combinator: ' ' | '>';
}

class CssQuery {
  static escapeId(id: string): string {
    return id.replace(/([!"#$%&'()*+,./:;<=>?@[\\\]^`{|}~])/g, '\\$1');
  }

  static findFirst(root: HtmlTreeNode, selector: string): HtmlTreeNode | null {
    const all = CssQuery.findAll(root, selector);
    return all.length > 0 ? all[0] : null;
  }

  static findAll(root: HtmlTreeNode, selector: string): HtmlTreeNode[] {
    const trimmed = selector.trim();
    if (trimmed.length === 0) {
      return [];
    }
    const chains = CssQuery.parseSelector(trimmed);
    const out: HtmlTreeNode[] = [];
    CssQuery.walkElements(root, (el: HtmlTreeNode) => {
      if (CssQuery.matchesChain(el, chains)) {
        out.push(el);
      }
    });
    return out;
  }

  private static walkElements(node: HtmlTreeNode, visitor: (el: HtmlTreeNode) => void): void {
    if (node.nodeType === 'element') {
      visitor(node);
    }
    for (let i = 0; i < node.children.length; i++) {
      CssQuery.walkElements(node.children[i], visitor);
    }
  }

  private static parseSelector(selector: string): CssSelectorChain {
    const combinator: ' ' | '>' = selector.includes('>') ? '>' : ' ';
    const rawParts = combinator === '>' ?
      selector.split('>').map((s: string) => s.trim()) :
      selector.split(/\s+/).map((s: string) => s.trim());
    const parts: CssSimpleSelector[] = [];
    for (let i = 0; i < rawParts.length; i++) {
      parts.push(CssQuery.parseSimple(rawParts[i]));
    }
    return { parts: parts, combinator: combinator };
  }

  private static parseSimple(sel: string): CssSimpleSelector {
    const simple: CssSimpleSelector = { tag: null, id: null, classes: [], attrs: [] };
    let rest = sel.trim();
    const tagMatch = rest.match(/^([a-zA-Z][\w-]*)/);
    if (tagMatch) {
      simple.tag = tagMatch[1].toLowerCase();
      rest = rest.substring(tagMatch[0].length);
    }
    while (rest.length > 0) {
      if (rest.charAt(0) === '#') {
        const idMatch = rest.match(/^#([\w-]+)/);
        if (idMatch) {
          simple.id = idMatch[1];
          rest = rest.substring(idMatch[0].length);
          continue;
        }
      }
      if (rest.charAt(0) === '.') {
        const clsMatch = rest.match(/^\.([\w-]+)/);
        if (clsMatch) {
          simple.classes.push(clsMatch[1]);
          rest = rest.substring(clsMatch[0].length);
          continue;
        }
      }
      if (rest.charAt(0) === '[') {
        const attrMatch = rest.match(/^\[([\w-]+)(?:(\|=|~=|\^=|\$=|\*=|=)(?:"([^"]*)"|'([^']*)'|([\w-]+)))?\]/);
        if (attrMatch) {
          const rule: CssAttrRule = {
            name: attrMatch[1].toLowerCase(),
            op: attrMatch[2] ?? '',
            value: attrMatch[3] ?? attrMatch[4] ?? attrMatch[5] ?? ''
          };
          simple.attrs.push(rule);
          rest = rest.substring(attrMatch[0].length);
          continue;
        }
      }
      break;
    }
    return simple;
  }

  private static matchesChain(el: HtmlTreeNode, chain: CssSelectorChain): boolean {
    if (chain.parts.length === 0) {
      return false;
    }
    if (chain.combinator === ' ') {
      return CssQuery.matchesSimple(el, chain.parts[chain.parts.length - 1]) &&
        CssQuery.matchAncestors(el, chain.parts, chain.parts.length - 2);
    }
    if (!CssQuery.matchesSimple(el, chain.parts[chain.parts.length - 1])) {
      return false;
    }
    let current: HtmlTreeNode | null = el.parent;
    for (let i = chain.parts.length - 2; i >= 0; i--) {
      while (current !== null) {
        if (current.nodeType === 'element' && CssQuery.matchesSimple(current, chain.parts[i])) {
          break;
        }
        current = current.parent;
      }
      if (current === null) {
        return false;
      }
      current = current.parent;
    }
    return true;
  }

  private static matchAncestors(el: HtmlTreeNode, parts: CssSimpleSelector[], index: number): boolean {
    if (index < 0) {
      return true;
    }
    let current: HtmlTreeNode | null = el.parent;
    while (current !== null) {
      if (current.nodeType === 'element' && CssQuery.matchesSimple(current, parts[index])) {
        return CssQuery.matchAncestors(current, parts, index - 1);
      }
      current = current.parent;
    }
    return false;
  }

  private static matchesSimple(el: HtmlTreeNode, simple: CssSimpleSelector): boolean {
    if (el.nodeType !== 'element') {
      return false;
    }
    if (simple.tag !== null && el.tagName !== simple.tag) {
      return false;
    }
    if (simple.id !== null && (el.attributes['id'] ?? '') !== simple.id) {
      return false;
    }
    if (simple.classes.length > 0) {
      const cls = (el.attributes['class'] ?? '').split(/\s+/);
      for (let i = 0; i < simple.classes.length; i++) {
        if (cls.indexOf(simple.classes[i]) < 0) {
          return false;
        }
      }
    }
    for (let i = 0; i < simple.attrs.length; i++) {
      const rule = simple.attrs[i];
      const val = el.attributes[rule.name] ?? '';
      if (!CssQuery.matchAttr(val, rule.op, rule.value)) {
        return false;
      }
    }
    return true;
  }

  private static matchAttr(actual: string, op: string, expected: string): boolean {
    if (op === '' || op === '=') {
      return actual === expected;
    }
    if (op === '*=') {
      return actual.includes(expected);
    }
    if (op === '^=') {
      return actual.startsWith(expected);
    }
    if (op === '$=') {
      return actual.endsWith(expected);
    }
    if (op === '~=') {
      return actual.split(/\s+/).indexOf(expected) >= 0;
    }
    if (op === '|=') {
      return actual === expected || actual.startsWith(`${expected}-`);
    }
    return false;
  }
}

/** init.js html sendMessage 分发 */
export class JsHtmlDomService {
  private static instance: JsHtmlDomService;
  private documents: Map<number, HtmlDocumentWrapper> = new Map();
  private static readonly MAX_DOCS = 8;

  static getInstance(): JsHtmlDomService {
    if (!JsHtmlDomService.instance) {
      JsHtmlDomService.instance = new JsHtmlDomService();
    }
    return JsHtmlDomService.instance;
  }

  handle(payload: Record<string, Object>): Object | null {
    const fn = `${payload['function'] ?? ''}`;
    const docKey = JsHtmlDomService.toNumber(payload['key']);
    const elementDoc = JsHtmlDomService.toNumber(payload['doc']);

    switch (fn) {
      case 'parse': {
        const html = `${payload['data'] ?? ''}`;
        if (docKey === null) {
          return null;
        }
        if (this.documents.size >= JsHtmlDomService.MAX_DOCS) {
          const oldest = this.documents.keys().next().value as number;
          this.documents.delete(oldest);
          console.warn(`[JsHtmlDom] evicted document ${oldest}`);
        }
        this.documents.set(docKey, new HtmlDocumentWrapper(html));
        return null;
      }
      case 'dispose': {
        if (docKey !== null) {
          this.documents.delete(docKey);
        }
        return null;
      }
      case 'querySelector': {
        const doc = docKey !== null ? this.documents.get(docKey) : undefined;
        return doc?.querySelector(`${payload['query'] ?? ''}`) ?? null;
      }
      case 'querySelectorAll': {
        const doc = docKey !== null ? this.documents.get(docKey) : undefined;
        return doc?.querySelectorAll(`${payload['query'] ?? ''}`) ?? [];
      }
      case 'getElementById': {
        const doc = docKey !== null ? this.documents.get(docKey) : undefined;
        return doc?.getElementById(`${payload['id'] ?? ''}`) ?? null;
      }
      case 'getText':
        return this.withDoc(elementDoc, (d) => d.elementGetText(JsHtmlDomService.toNumber(payload['key']) ?? -1));
      case 'getAttributes':
        return this.withDoc(elementDoc, (d) => d.elementGetAttributes(JsHtmlDomService.toNumber(payload['key']) ?? -1));
      case 'dom_querySelector':
        return this.withDoc(elementDoc, (d) =>
          d.elementQuerySelector(JsHtmlDomService.toNumber(payload['key']) ?? -1, `${payload['query'] ?? ''}`));
      case 'dom_querySelectorAll':
        return this.withDoc(elementDoc, (d) =>
          d.elementQuerySelectorAll(JsHtmlDomService.toNumber(payload['key']) ?? -1, `${payload['query'] ?? ''}`));
      case 'getChildren':
        return this.withDoc(elementDoc, (d) => d.elementGetChildren(JsHtmlDomService.toNumber(payload['key']) ?? -1));
      case 'getNodes':
        return this.withDoc(elementDoc, (d) => d.elementGetNodes(JsHtmlDomService.toNumber(payload['key']) ?? -1));
      case 'getInnerHTML':
        return this.withDoc(elementDoc, (d) => d.elementGetInnerHTML(JsHtmlDomService.toNumber(payload['key']) ?? -1));
      case 'getParent':
        return this.withDoc(elementDoc, (d) => d.elementGetParent(JsHtmlDomService.toNumber(payload['key']) ?? -1));
      case 'getClassNames':
        return this.withDoc(elementDoc, (d) => d.getClassNames(JsHtmlDomService.toNumber(payload['key']) ?? -1));
      case 'getId':
        return this.withDoc(elementDoc, (d) => d.getId(JsHtmlDomService.toNumber(payload['key']) ?? -1));
      case 'getLocalName':
        return this.withDoc(elementDoc, (d) => d.getLocalName(JsHtmlDomService.toNumber(payload['key']) ?? -1));
      case 'getPreviousSibling':
        return this.withDoc(elementDoc, (d) => d.getPreviousSibling(JsHtmlDomService.toNumber(payload['key']) ?? -1));
      case 'getNextSibling':
        return this.withDoc(elementDoc, (d) => d.getNextSibling(JsHtmlDomService.toNumber(payload['key']) ?? -1));
      case 'node_text':
        return this.withDoc(elementDoc, (d) => d.nodeGetText(JsHtmlDomService.toNumber(payload['key']) ?? -1));
      case 'node_type':
        return this.withDoc(elementDoc, (d) => d.nodeType(JsHtmlDomService.toNumber(payload['key']) ?? -1));
      case 'node_toElement':
        return this.withDoc(elementDoc, (d) => d.nodeToElement(JsHtmlDomService.toNumber(payload['key']) ?? -1));
      default:
        console.warn(`[JsHtmlDom] unknown function: ${fn}`);
        return null;
    }
  }

  private withDoc<T>(docKey: number | null, fn: (doc: HtmlDocumentWrapper) => T | null): T | null {
    if (docKey === null) {
      return null;
    }
    const doc = this.documents.get(docKey);
    if (!doc) {
      return null;
    }
    return fn(doc);
  }

  private static toNumber(value: Object | undefined): number | null {
    if (value === undefined || value === null) {
      return null;
    }
    if (typeof value === 'number') {
      return value;
    }
    const n = Number(`${value}`);
    return isNaN(n) ? null : n;
  }
}
