#include "venera_archive.h"

#include <string>

#ifndef VENERA_HAS_LZMA_SDK

bool venera_extract_7z(const std::string &archivePath, const std::string &outDir, std::string &errorOut)
{
    (void)archivePath;
    (void)outDir;
    errorOut = "7z: run scripts/fetch-lzma.ps1 then rebuild native module";
    return false;
}

#else

extern "C" {
#include "7z.h"
#include "7zAlloc.h"
#include "7zBuf.h"
#include "7zCrc.h"
#include "7zFile.h"
}

static ISzAlloc g_alloc = { SzAlloc, SzFree };

bool venera_extract_7z(const std::string &archivePath, const std::string &outDir, std::string &errorOut)
{
    if (archivePath.empty() || outDir.empty()) {
        errorOut = "invalid path";
        return false;
    }
    CFileInStream archiveStream;
    CLookToRead2 lookStream;
    CSzArEx db;
    SRes res = SZ_OK;
    UInt32 blockIndex = 0xFFFFFFFF;
    Byte *outBuffer = 0;
    size_t outBufferSize = 0;

    FileInStream_CreateVTable(&archiveStream);
    LookToRead2_CreateVTable(&lookStream, False);
    lookStream.realStream = &archiveStream.vt;
    lookStream.buf = 0;

    if (InFile_Open(&archiveStream.file, archivePath.c_str()) != 0) {
        errorOut = "cannot open archive";
        return false;
    }
    lookStream.buf = (Byte *)ISzAlloc_Alloc(&g_alloc, (size_t)1 << 18);
    if (!lookStream.buf) {
        errorOut = "alloc failed";
        File_Close(&archiveStream.file);
        return false;
    }
    lookStream.bufSize = (size_t)1 << 18;
    lookStream.allocMain = &g_alloc;
    LookToRead2_INIT(&lookStream);

    SzArEx_Init(&db);
    res = SzArEx_Open(&db, &lookStream.vt, &g_alloc, &g_alloc);
    if (res != SZ_OK) {
        errorOut = "7z open failed";
        SzArEx_Free(&db, &g_alloc);
        File_Close(&archiveStream.file);
        ISzAlloc_Free(&g_alloc, lookStream.buf);
        return false;
    }

    for (UInt32 i = 0; i < db.NumFiles; i++) {
        if (SzArEx_IsDir(&db, i)) {
            continue;
        }
        size_t offset = 0;
        size_t outSizeProcessed = 0;
        res = SzArEx_Extract(&db, &lookStream.vt, i, &blockIndex, &outBuffer, &outBufferSize,
            &offset, &outSizeProcessed, &g_alloc, &g_alloc);
        if (res != SZ_OK) {
            errorOut = "extract failed";
            break;
        }
        const char *name = SzArEx_GetFileNameUtf8(&db, i);
        if (!name) {
            continue;
        }
        std::string outPath = outDir + "/" + name;
        CFileSeqOutStream outStream;
        FileOutStream_CreateVTable(&outStream);
        if (OutFile_Open(&outStream.file, outPath.c_str()) != 0) {
            errorOut = "cannot write output";
            res = SZ_ERROR_WRITE;
            break;
        }
        if (SeqOutStream_Write(&outStream.s, outBuffer + offset, outSizeProcessed) != outSizeProcessed) {
            File_Close(&outStream.file);
            errorOut = "write failed";
            res = SZ_ERROR_WRITE;
            break;
        }
        File_Close(&outStream.file);
    }

    ISzAlloc_Free(&g_alloc, outBuffer);
    SzArEx_Free(&db, &g_alloc);
    File_Close(&archiveStream.file);
    ISzAlloc_Free(&g_alloc, lookStream.buf);
    return res == SZ_OK;
}

#endif
