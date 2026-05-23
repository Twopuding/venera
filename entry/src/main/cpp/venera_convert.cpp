#include "venera_convert.h"

#include <cctype>
#include <cstdint>
#include <cstring>
#include <sstream>
#include <string>
#include <vector>

namespace {

std::string json_escape(const std::string &s)
{
    std::ostringstream out;
    for (char c : s) {
        if (c == '"') {
            out << "\\\"";
        } else if (c == '\\') {
            out << "\\\\";
        } else if (c == '\n') {
            out << "\\n";
        } else if (c == '\r') {
            out << "\\r";
        } else if (c == '\t') {
            out << "\\t";
        } else if (static_cast<unsigned char>(c) < 0x20) {
            out << ' ';
        } else {
            out << c;
        }
    }
    return out.str();
}

std::string extract_field_string(const std::string &json, const char *field)
{
    std::string token = std::string("\"") + field + "\"";
    size_t pos = json.find(token);
    if (pos == std::string::npos) {
        return "";
    }
    pos = json.find(':', pos);
    if (pos == std::string::npos) {
        return "";
    }
    while (pos + 1 < json.size() && std::isspace(static_cast<unsigned char>(json[pos + 1]))) {
        pos++;
    }
    if (pos + 1 < json.size() && json[pos + 1] == '"') {
        size_t start = pos + 2;
        size_t end = json.find('"', start);
        if (end == std::string::npos) {
            return "";
        }
        return json.substr(start, end - start);
    }
    return "";
}

bool extract_field_bool(const std::string &json, const char *field, bool defaultValue)
{
    std::string token = std::string("\"") + field + "\"";
    size_t pos = json.find(token);
    if (pos == std::string::npos) {
        return defaultValue;
    }
    pos = json.find(':', pos);
    if (pos == std::string::npos) {
        return defaultValue;
    }
    size_t t = json.find("true", pos);
    size_t f = json.find("false", pos);
    if (t != std::string::npos && (f == std::string::npos || t < f)) {
        return true;
    }
    if (f != std::string::npos) {
        return false;
    }
    return defaultValue;
}

std::vector<uint8_t> parse_field_bytes(const std::string &json, const char *field)
{
    std::string token = std::string("\"") + field + "\"";
    size_t pos = json.find(token);
    if (pos == std::string::npos) {
        return {};
    }
    pos = json.find(':', pos);
    if (pos == std::string::npos) {
        return {};
    }
    while (pos + 1 < json.size() && std::isspace(static_cast<unsigned char>(json[pos + 1]))) {
        pos++;
    }
    if (pos + 1 >= json.size()) {
        return {};
    }
    if (json[pos + 1] == '"') {
        size_t start = pos + 2;
        size_t end = json.find('"', start);
        if (end == std::string::npos) {
            return {};
        }
        std::string s = json.substr(start, end - start);
        return std::vector<uint8_t>(s.begin(), s.end());
    }
    if (json[pos + 1] != '[') {
        return {};
    }
    size_t i = pos + 2;
    std::vector<uint8_t> out;
    while (i < json.size()) {
        while (i < json.size() && (std::isspace(static_cast<unsigned char>(json[i])) || json[i] == ',')) {
            i++;
        }
        if (i >= json.size() || json[i] == ']') {
            break;
        }
        if (!std::isdigit(static_cast<unsigned char>(json[i])) && json[i] != '-') {
            break;
        }
        long v = std::strtol(json.c_str() + i, nullptr, 10);
        if (v < 0) {
            v = 0;
        }
        if (v > 255) {
            v = 255;
        }
        out.push_back(static_cast<uint8_t>(v));
        while (i < json.size() && (std::isdigit(static_cast<unsigned char>(json[i])) || json[i] == '-')) {
            i++;
        }
    }
    return out;
}

std::string bytes_to_hex(const uint8_t *data, size_t len)
{
    static const char *hex = "0123456789abcdef";
    std::string out;
    out.reserve(len * 2);
    for (size_t i = 0; i < len; i++) {
        out.push_back(hex[(data[i] >> 4) & 0xf]);
        out.push_back(hex[data[i] & 0xf]);
    }
    return out;
}

std::string bytes_to_json_array(const std::vector<uint8_t> &bytes)
{
    std::ostringstream out;
    out << '[';
    for (size_t i = 0; i < bytes.size(); i++) {
        if (i > 0) {
            out << ',';
        }
        out << static_cast<int>(bytes[i]);
    }
    out << ']';
    return out.str();
}

static const char BASE64_CHARS[] =
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

std::string base64_encode(const std::vector<uint8_t> &data)
{
    std::string out;
    size_t i = 0;
    while (i < data.size()) {
        uint32_t octet_a = i < data.size() ? data[i++] : 0;
        uint32_t octet_b = i < data.size() ? data[i++] : 0;
        uint32_t octet_c = i < data.size() ? data[i++] : 0;
        uint32_t triple = (octet_a << 16) | (octet_b << 8) | octet_c;
        out.push_back(BASE64_CHARS[(triple >> 18) & 0x3F]);
        out.push_back(BASE64_CHARS[(triple >> 12) & 0x3F]);
        out.push_back(BASE64_CHARS[(triple >> 6) & 0x3F]);
        out.push_back(BASE64_CHARS[triple & 0x3F]);
    }
    size_t mod = data.size() % 3;
    if (mod > 0) {
        out[out.size() - 1] = '=';
        if (mod == 1) {
            out[out.size() - 2] = '=';
        }
    }
    return out;
}

std::vector<uint8_t> base64_decode(const std::string &text)
{
    auto val = [](char c) -> int {
        if (c >= 'A' && c <= 'Z') {
            return c - 'A';
        }
        if (c >= 'a' && c <= 'z') {
            return c - 'a' + 26;
        }
        if (c >= '0' && c <= '9') {
            return c - '0' + 52;
        }
        if (c == '+') {
            return 62;
        }
        if (c == '/') {
            return 63;
        }
        return -1;
    };
    std::vector<uint8_t> out;
    int buffer = 0;
    int bits = 0;
    for (char c : text) {
        if (c == '=' || c == '\n' || c == '\r') {
            continue;
        }
        int v = val(c);
        if (v < 0) {
            continue;
        }
        buffer = (buffer << 6) | v;
        bits += 6;
        if (bits >= 8) {
            bits -= 8;
            out.push_back(static_cast<uint8_t>((buffer >> bits) & 0xFF));
        }
    }
    return out;
}

// --- MD5 (RFC 1321, compact) ---
struct Md5Ctx {
    uint32_t state[4];
    uint64_t count;
    uint8_t buffer[64];
};

static inline uint32_t md5_f(uint32_t x, uint32_t y, uint32_t z)
{
    return (x & y) | (~x & z);
}
static inline uint32_t md5_g(uint32_t x, uint32_t y, uint32_t z)
{
    return (x & z) | (y & ~z);
}
static inline uint32_t md5_h(uint32_t x, uint32_t y, uint32_t z)
{
    return x ^ y ^ z;
}
static inline uint32_t md5_i(uint32_t x, uint32_t y, uint32_t z)
{
    return y ^ (x | ~z);
}
static inline uint32_t md5_rotl(uint32_t x, int n)
{
    return (x << n) | (x >> (32 - n));
}

static void md5_transform(uint32_t state[4], const uint8_t block[64])
{
    uint32_t a = state[0];
    uint32_t b = state[1];
    uint32_t c = state[2];
    uint32_t d = state[3];
    uint32_t x[16];
    for (int i = 0; i < 16; i++) {
        x[i] = static_cast<uint32_t>(block[i * 4]) | (static_cast<uint32_t>(block[i * 4 + 1]) << 8) |
               (static_cast<uint32_t>(block[i * 4 + 2]) << 16) | (static_cast<uint32_t>(block[i * 4 + 3]) << 24);
    }
#define MD5STEP(f, a, b, c, d, x, t, s) \
    a += f(b, c, d) + x + t;          \
    a = md5_rotl(a, s);               \
    a += b;
    MD5STEP(md5_f, a, b, c, d, x[0], 0xd76aa478, 7);
    MD5STEP(md5_f, d, a, b, c, x[1], 0xe8c7b756, 12);
    MD5STEP(md5_f, c, d, a, b, x[2], 0x242070db, 17);
    MD5STEP(md5_f, b, c, d, a, x[3], 0xc1bdceee, 22);
    MD5STEP(md5_f, a, b, c, d, x[4], 0xf57c0faf, 7);
    MD5STEP(md5_f, d, a, b, c, x[5], 0x4787c62a, 12);
    MD5STEP(md5_f, c, d, a, b, x[6], 0xa8304613, 17);
    MD5STEP(md5_f, b, c, d, a, x[7], 0xfd469501, 22);
    MD5STEP(md5_f, a, b, c, d, x[8], 0x698098d8, 7);
    MD5STEP(md5_f, d, a, b, c, x[9], 0x8b44f7af, 12);
    MD5STEP(md5_f, c, d, a, b, x[10], 0xffff5bb1, 17);
    MD5STEP(md5_f, b, c, d, a, x[11], 0x895cd7be, 22);
    MD5STEP(md5_f, a, b, c, d, x[12], 0x6b901122, 7);
    MD5STEP(md5_f, d, a, b, c, x[13], 0xfd987193, 12);
    MD5STEP(md5_f, c, d, a, b, x[14], 0xa679438e, 17);
    MD5STEP(md5_f, b, c, d, a, x[15], 0x49b40821, 22);
    MD5STEP(md5_g, a, b, c, d, x[1], 0xf61e2562, 5);
    MD5STEP(md5_g, d, a, b, c, x[6], 0xc040b340, 9);
    MD5STEP(md5_g, c, d, a, b, x[11], 0x265e5a51, 14);
    MD5STEP(md5_g, b, c, d, a, x[0], 0xe9b6c7aa, 20);
    MD5STEP(md5_g, a, b, c, d, x[5], 0xd62f105d, 5);
    MD5STEP(md5_g, d, a, b, c, x[10], 0x02441453, 9);
    MD5STEP(md5_g, c, d, a, b, x[15], 0xd8a1e681, 14);
    MD5STEP(md5_g, b, c, d, a, x[4], 0xe7d3fbc8, 20);
    MD5STEP(md5_g, a, b, c, d, x[9], 0x21e1cde6, 5);
    MD5STEP(md5_g, d, a, b, c, x[14], 0xc33707d6, 9);
    MD5STEP(md5_g, c, d, a, b, x[3], 0xf4d50d87, 14);
    MD5STEP(md5_g, b, c, d, a, x[8], 0x455a14ed, 20);
    MD5STEP(md5_g, a, b, c, d, x[13], 0xa9e3e905, 5);
    MD5STEP(md5_g, d, a, b, c, x[2], 0xfcefa3f8, 9);
    MD5STEP(md5_g, c, d, a, b, x[7], 0x676f02d9, 14);
    MD5STEP(md5_g, b, c, d, a, x[12], 0x8d2a4c8a, 20);
    MD5STEP(md5_h, a, b, c, d, x[5], 0xfffa3942, 4);
    MD5STEP(md5_h, d, a, b, c, x[8], 0x8771f681, 11);
    MD5STEP(md5_h, c, d, a, b, x[11], 0x6d9d6122, 16);
    MD5STEP(md5_h, b, c, d, a, x[14], 0xfde5380c, 23);
    MD5STEP(md5_h, a, b, c, d, x[1], 0xa4beea44, 4);
    MD5STEP(md5_h, d, a, b, c, x[4], 0x4bdecfa9, 11);
    MD5STEP(md5_h, c, d, a, b, x[7], 0xf6bb4b60, 16);
    MD5STEP(md5_h, b, c, d, a, x[10], 0xbebfbc70, 23);
    MD5STEP(md5_h, a, b, c, d, x[13], 0x289b7ec6, 4);
    MD5STEP(md5_h, d, a, b, c, x[0], 0xeaa127fa, 11);
    MD5STEP(md5_h, c, d, a, b, x[3], 0xd4ef3085, 16);
    MD5STEP(md5_h, b, c, d, a, x[6], 0x04881d05, 23);
    MD5STEP(md5_h, a, b, c, d, x[9], 0xd9d4d039, 4);
    MD5STEP(md5_h, d, a, b, c, x[12], 0xe6db99e5, 11);
    MD5STEP(md5_h, c, d, a, b, x[15], 0x1fa27cf8, 16);
    MD5STEP(md5_h, b, c, d, a, x[2], 0xc4ac5665, 23);
    MD5STEP(md5_i, a, b, c, d, x[0], 0xf4292244, 6);
    MD5STEP(md5_i, d, a, b, c, x[7], 0x432aff97, 10);
    MD5STEP(md5_i, c, d, a, b, x[14], 0xab9423a7, 15);
    MD5STEP(md5_i, b, c, d, a, x[5], 0xfc93a039, 21);
    MD5STEP(md5_i, a, b, c, d, x[12], 0x655b59c3, 6);
    MD5STEP(md5_i, d, a, b, c, x[3], 0x8f0ccc92, 10);
    MD5STEP(md5_i, c, d, a, b, x[10], 0xffeff47d, 15);
    MD5STEP(md5_i, b, c, d, a, x[1], 0x85845dd1, 21);
    MD5STEP(md5_i, a, b, c, d, x[8], 0x6fa87e4f, 6);
    MD5STEP(md5_i, d, a, b, c, x[15], 0xfe2ce6e0, 10);
    MD5STEP(md5_i, c, d, a, b, x[6], 0xa3014314, 15);
    MD5STEP(md5_i, b, c, d, a, x[13], 0x4e0811a1, 21);
    MD5STEP(md5_i, a, b, c, d, x[4], 0xf7537e82, 6);
    MD5STEP(md5_i, d, a, b, c, x[11], 0xbd3af235, 10);
    MD5STEP(md5_i, c, d, a, b, x[2], 0x2ad7d2bb, 15);
    MD5STEP(md5_i, b, c, d, a, x[9], 0xeb86d391, 21);
#undef MD5STEP
    state[0] += a;
    state[1] += b;
    state[2] += c;
    state[3] += d;
}

static void md5_init(Md5Ctx *ctx)
{
    ctx->count = 0;
    ctx->state[0] = 0x67452301;
    ctx->state[1] = 0xefcdab89;
    ctx->state[2] = 0x98badcfe;
    ctx->state[3] = 0x10325476;
}

static void md5_update(Md5Ctx *ctx, const uint8_t *data, size_t len)
{
    size_t index = static_cast<size_t>((ctx->count >> 3) & 0x3f);
    ctx->count += static_cast<uint64_t>(len) << 3;
    size_t partLen = 64 - index;
    size_t i = 0;
    if (len >= partLen) {
        memcpy(ctx->buffer + index, data, partLen);
        md5_transform(ctx->state, ctx->buffer);
        for (i = partLen; i + 63 < len; i += 64) {
            md5_transform(ctx->state, data + i);
        }
        index = 0;
    }
    memcpy(ctx->buffer + index, data + i, len - i);
}

static void md5_final(Md5Ctx *ctx, uint8_t digest[16])
{
    static const uint8_t padding[64] = { 0x80 };
    uint8_t bits[8];
    for (int i = 0; i < 8; i++) {
        bits[i] = static_cast<uint8_t>((ctx->count >> (i * 8)) & 0xff);
    }
    size_t index = static_cast<size_t>((ctx->count >> 3) & 0x3f);
    size_t padLen = (index < 56) ? (56 - index) : (120 - index);
    md5_update(ctx, padding, padLen);
    md5_update(ctx, bits, 8);
    for (int i = 0; i < 4; i++) {
        digest[i * 4] = static_cast<uint8_t>(ctx->state[i] & 0xff);
        digest[i * 4 + 1] = static_cast<uint8_t>((ctx->state[i] >> 8) & 0xff);
        digest[i * 4 + 2] = static_cast<uint8_t>((ctx->state[i] >> 16) & 0xff);
        digest[i * 4 + 3] = static_cast<uint8_t>((ctx->state[i] >> 24) & 0xff);
    }
}

std::vector<uint8_t> md5_digest(const std::vector<uint8_t> &data)
{
    Md5Ctx ctx;
    md5_init(&ctx);
    if (!data.empty()) {
        md5_update(&ctx, data.data(), data.size());
    }
    std::vector<uint8_t> out(16);
    md5_final(&ctx, out.data());
    return out;
}

// --- SHA-256 ---
struct Sha256Ctx {
    uint8_t data[64];
    uint32_t datalen;
    uint64_t bitlen;
    uint32_t state[8];
};

static const uint32_t SHA256_K[64] = {
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
};

static inline uint32_t sha256_rotr(uint32_t x, uint32_t n)
{
    return (x >> n) | (x << (32 - n));
}

static void sha256_transform(Sha256Ctx *ctx, const uint8_t data[])
{
    uint32_t m[64];
    for (int i = 0; i < 16; i++) {
        m[i] = (static_cast<uint32_t>(data[i * 4]) << 24) | (static_cast<uint32_t>(data[i * 4 + 1]) << 16) |
               (static_cast<uint32_t>(data[i * 4 + 2]) << 8) | static_cast<uint32_t>(data[i * 4 + 3]);
    }
    for (int i = 16; i < 64; i++) {
        uint32_t s0 = sha256_rotr(m[i - 15], 7) ^ sha256_rotr(m[i - 15], 18) ^ (m[i - 15] >> 3);
        uint32_t s1 = sha256_rotr(m[i - 2], 17) ^ sha256_rotr(m[i - 2], 19) ^ (m[i - 2] >> 10);
        m[i] = m[i - 16] + s0 + m[i - 7] + s1;
    }
    uint32_t a = ctx->state[0];
    uint32_t b = ctx->state[1];
    uint32_t c = ctx->state[2];
    uint32_t d = ctx->state[3];
    uint32_t e = ctx->state[4];
    uint32_t f = ctx->state[5];
    uint32_t g = ctx->state[6];
    uint32_t h = ctx->state[7];
    for (int i = 0; i < 64; i++) {
        uint32_t s1 = sha256_rotr(e, 6) ^ sha256_rotr(e, 11) ^ sha256_rotr(e, 25);
        uint32_t ch = (e & f) ^ (~e & g);
        uint32_t t1 = h + s1 + ch + SHA256_K[i] + m[i];
        uint32_t s0 = sha256_rotr(a, 2) ^ sha256_rotr(a, 13) ^ sha256_rotr(a, 22);
        uint32_t maj = (a & b) ^ (a & c) ^ (b & c);
        uint32_t t2 = s0 + maj;
        h = g;
        g = f;
        f = e;
        e = d + t1;
        d = c;
        c = b;
        b = a;
        a = t1 + t2;
    }
    ctx->state[0] += a;
    ctx->state[1] += b;
    ctx->state[2] += c;
    ctx->state[3] += d;
    ctx->state[4] += e;
    ctx->state[5] += f;
    ctx->state[6] += g;
    ctx->state[7] += h;
}

static void sha256_init(Sha256Ctx *ctx)
{
    ctx->datalen = 0;
    ctx->bitlen = 0;
    ctx->state[0] = 0x6a09e667;
    ctx->state[1] = 0xbb67ae85;
    ctx->state[2] = 0x3c6ef372;
    ctx->state[3] = 0xa54ff53a;
    ctx->state[4] = 0x510e527f;
    ctx->state[5] = 0x9b05688c;
    ctx->state[6] = 0x1f83d9ab;
    ctx->state[7] = 0x5be0cd19;
}

static void sha256_update(Sha256Ctx *ctx, const uint8_t *data, size_t len)
{
    for (size_t i = 0; i < len; i++) {
        ctx->data[ctx->datalen] = data[i];
        ctx->datalen++;
        if (ctx->datalen == 64) {
            sha256_transform(ctx, ctx->data);
            ctx->bitlen += 512;
            ctx->datalen = 0;
        }
    }
}

static void sha256_final(Sha256Ctx *ctx, uint8_t hash[])
{
    uint32_t i = ctx->datalen;
    if (ctx->datalen < 56) {
        ctx->data[i++] = 0x80;
        while (i < 56) {
            ctx->data[i++] = 0x00;
        }
    } else {
        ctx->data[i++] = 0x80;
        while (i < 64) {
            ctx->data[i++] = 0x00;
        }
        sha256_transform(ctx, ctx->data);
        memset(ctx->data, 0, 56);
    }
    ctx->bitlen += static_cast<uint64_t>(ctx->datalen) * 8;
    ctx->data[63] = static_cast<uint8_t>(ctx->bitlen);
    ctx->data[62] = static_cast<uint8_t>(ctx->bitlen >> 8);
    ctx->data[61] = static_cast<uint8_t>(ctx->bitlen >> 16);
    ctx->data[60] = static_cast<uint8_t>(ctx->bitlen >> 24);
    ctx->data[59] = static_cast<uint8_t>(ctx->bitlen >> 32);
    ctx->data[58] = static_cast<uint8_t>(ctx->bitlen >> 40);
    ctx->data[57] = static_cast<uint8_t>(ctx->bitlen >> 48);
    ctx->data[56] = static_cast<uint8_t>(ctx->bitlen >> 56);
    sha256_transform(ctx, ctx->data);
    for (int j = 0; j < 8; j++) {
        hash[j * 4] = static_cast<uint8_t>((ctx->state[j] >> 24) & 0xff);
        hash[j * 4 + 1] = static_cast<uint8_t>((ctx->state[j] >> 16) & 0xff);
        hash[j * 4 + 2] = static_cast<uint8_t>((ctx->state[j] >> 8) & 0xff);
        hash[j * 4 + 3] = static_cast<uint8_t>(ctx->state[j] & 0xff);
    }
}

std::vector<uint8_t> sha256_digest(const std::vector<uint8_t> &data)
{
    Sha256Ctx ctx;
    sha256_init(&ctx);
    if (!data.empty()) {
        sha256_update(&ctx, data.data(), data.size());
    }
    std::vector<uint8_t> out(32);
    sha256_final(&ctx, out.data());
    return out;
}

// SHA-1 and SHA-512 via SHA-256 family patterns (SHA-1 full impl)
struct Sha1Ctx {
    uint32_t state[5];
    uint64_t count;
    uint8_t buffer[64];
};

static void sha1_transform(uint32_t state[5], const uint8_t block[64])
{
    uint32_t w[80];
    for (int i = 0; i < 16; i++) {
        w[i] = (static_cast<uint32_t>(block[i * 4]) << 24) | (static_cast<uint32_t>(block[i * 4 + 1]) << 16) |
               (static_cast<uint32_t>(block[i * 4 + 2]) << 8) | static_cast<uint32_t>(block[i * 4 + 3]);
    }
    for (int i = 16; i < 80; i++) {
        w[i] = sha256_rotr(w[i - 3] ^ w[i - 8] ^ w[i - 14] ^ w[i - 16], 1);
    }
    uint32_t a = state[0];
    uint32_t b = state[1];
    uint32_t c = state[2];
    uint32_t d = state[3];
    uint32_t e = state[4];
    for (int i = 0; i < 80; i++) {
        uint32_t f = 0;
        uint32_t k = 0;
        if (i < 20) {
            f = (b & c) | ((~b) & d);
            k = 0x5a827999;
        } else if (i < 40) {
            f = b ^ c ^ d;
            k = 0x6ed9eba1;
        } else if (i < 60) {
            f = (b & c) | (b & d) | (c & d);
            k = 0x8f1bbcdc;
        } else {
            f = b ^ c ^ d;
            k = 0xca62c1d6;
        }
        uint32_t temp = sha256_rotr(a, 27) + f + e + k + w[i];
        e = d;
        d = c;
        c = sha256_rotr(b, 2);
        b = a;
        a = temp;
    }
    state[0] += a;
    state[1] += b;
    state[2] += c;
    state[3] += d;
    state[4] += e;
}

static void sha1_update(Sha1Ctx *ctx, const uint8_t *data, size_t len)
{
    size_t index = static_cast<size_t>((ctx->count >> 3) & 0x3f);
    ctx->count += static_cast<uint64_t>(len) << 3;
    size_t partLen = 64 - index;
    size_t i = 0;
    if (len >= partLen) {
        memcpy(ctx->buffer + index, data, partLen);
        sha1_transform(ctx->state, ctx->buffer);
        for (i = partLen; i + 63 < len; i += 64) {
            sha1_transform(ctx->state, data + i);
        }
        index = 0;
    }
    memcpy(ctx->buffer + index, data + i, len - i);
}

static void sha1_final(Sha1Ctx *ctx, uint8_t digest[20])
{
    static const uint8_t padding[64] = { 0x80 };
    uint8_t bits[8];
    for (int i = 0; i < 8; i++) {
        bits[i] = static_cast<uint8_t>((ctx->count >> (i * 8)) & 0xff);
    }
    size_t index = static_cast<size_t>((ctx->count >> 3) & 0x3f);
    size_t padLen = (index < 56) ? (56 - index) : (120 - index);
    sha1_update(ctx, padding, padLen);
    sha1_update(ctx, bits, 8);
    for (int i = 0; i < 5; i++) {
        digest[i * 4] = static_cast<uint8_t>((ctx->state[i] >> 24) & 0xff);
        digest[i * 4 + 1] = static_cast<uint8_t>((ctx->state[i] >> 16) & 0xff);
        digest[i * 4 + 2] = static_cast<uint8_t>((ctx->state[i] >> 8) & 0xff);
        digest[i * 4 + 3] = static_cast<uint8_t>(ctx->state[i] & 0xff);
    }
}

std::vector<uint8_t> sha1_digest(const std::vector<uint8_t> &data)
{
    Sha1Ctx ctx;
    ctx.count = 0;
    ctx.state[0] = 0x67452301;
    ctx.state[1] = 0xefcdab89;
    ctx.state[2] = 0x98badcfe;
    ctx.state[3] = 0x10325476;
    ctx.state[4] = 0xc3d2e1f0;
    if (!data.empty()) {
        sha1_update(&ctx, data.data(), data.size());
    }
    std::vector<uint8_t> out(20);
    sha1_final(&ctx, out.data());
    return out;
}

// SHA-512 (uint64_t)
struct Sha512Ctx {
    uint64_t state[8];
    uint64_t count[2];
    uint8_t buffer[128];
};

static const uint64_t SHA512_K[80] = {
    0x428a2f98d728ae22ULL, 0x7137449123ef65cdULL, 0xb5c0fbcfec4d3b2fULL, 0xe9b5dba58189dbbcULL,
    0x3956c25bf348b538ULL, 0x59f111f1b605d019ULL, 0x923f82a4af194f9bULL, 0xab1c5ed5da6d8118ULL,
    0xd807aa98a3030242ULL, 0x12835b0145706fbeULL, 0x243185be4ee4b28cULL, 0x550c7dc3d5ffb4e2ULL,
    0x72be5d74f27b896fULL, 0x80deb1fe3b1696b1ULL, 0x9bdc06a725c71235ULL, 0xc19bf174cf692694ULL,
    0xe49b69c19ef14ad2ULL, 0xefbe4786384f25e3ULL, 0x0fc19dc68b8cd5b5ULL, 0x240ca1cc77ac9c65ULL,
    0x2de92c6f592b0275ULL, 0x4a7484aa6ea6e483ULL, 0x5cb0a9dcbd41fbd4ULL, 0x76f988da831153b5ULL,
    0x983e5152ee66dfabULL, 0xa831c66d2db43210ULL, 0xb00327c898fb213fULL, 0xbf597fc7beef0ee4ULL,
    0xc6e00bf33da88fc2ULL, 0xd5a79147930aa725ULL, 0x06ca6351e003826fULL, 0x142929670a0e6e70ULL,
    0x27b70a8546d22ffcULL, 0x2e1b21385c26c926ULL, 0x4d2c6dfc5ac42aedULL, 0x53380d139d95b3dfULL,
    0x650a73548baf63deULL, 0x766a0abb3c77b2a8ULL, 0x81c2c92e47edaee6ULL, 0x92722c851482353bULL,
    0xa2bfe8a14cf10364ULL, 0xa81a664bbc423001ULL, 0xc24b8b70d0f89791ULL, 0xc76c51a30654be30ULL,
    0xd192e819d6ef5218ULL, 0xd69906245565a910ULL, 0xf40e35855771202aULL, 0x106aa07032bbd1b8ULL,
    0x19a4c116b8d2d0c8ULL, 0x1e376c085141ab53ULL, 0x2748774cdf8eeb99ULL, 0x34b0bcb5e19b48a8ULL,
    0x391c0cb3c5c95a63ULL, 0x4ed8aa4ae3418acbULL, 0x5b9cca4f7763e373ULL, 0x682e6ff3d6b2b8a3ULL,
    0x748f82ee5defb2fcULL, 0x78a5636f43172f60ULL, 0x84c87814a1f0ab72ULL, 0x8cc702081a6439ecULL,
    0x90befffa23631e28ULL, 0xa4506cebde82bde9ULL, 0xbef9a3f7b2c67915ULL, 0xc67178f2e372532bULL,
    0xca273eceea26619cULL, 0xd186b8c721c0c207ULL, 0xeada7dd6cde0eb1eULL, 0xf57d4f7fee6ed178ULL,
    0x06f067aa72176fbaULL, 0x0a637dc5a2c898a6ULL, 0x113f9804bef90daeULL, 0x1b710b35131c471bULL,
    0x28db77f523047d84ULL, 0x32caab7b40c72493ULL, 0x3c9ebe0a15c9bebcULL, 0x431d67c49c100d4cULL,
    0x4cc5d4becb3e42b6ULL, 0x597f299cfc657e2aULL, 0x5fcb6fab3ad6faecULL, 0x6c44198c4a475817ULL
};

static inline uint64_t sha512_rotr(uint64_t x, uint64_t n)
{
    return (x >> n) | (x << (64 - n));
}

static void sha512_transform(Sha512Ctx *ctx, const uint8_t block[128])
{
    uint64_t w[80];
    for (int i = 0; i < 16; i++) {
        w[i] = 0;
        for (int j = 0; j < 8; j++) {
            w[i] = (w[i] << 8) | block[i * 8 + j];
        }
    }
    for (int i = 16; i < 80; i++) {
        uint64_t s0 = sha512_rotr(w[i - 15], 1) ^ sha512_rotr(w[i - 15], 8) ^ (w[i - 15] >> 7);
        uint64_t s1 = sha512_rotr(w[i - 2], 19) ^ sha512_rotr(w[i - 2], 61) ^ (w[i - 2] >> 6);
        w[i] = w[i - 16] + s0 + w[i - 7] + s1;
    }
    uint64_t a = ctx->state[0];
    uint64_t b = ctx->state[1];
    uint64_t c = ctx->state[2];
    uint64_t d = ctx->state[3];
    uint64_t e = ctx->state[4];
    uint64_t f = ctx->state[5];
    uint64_t g = ctx->state[6];
    uint64_t h = ctx->state[7];
    for (int i = 0; i < 80; i++) {
        uint64_t s1 = sha512_rotr(e, 14) ^ sha512_rotr(e, 18) ^ sha512_rotr(e, 41);
        uint64_t ch = (e & f) ^ (~e & g);
        uint64_t t1 = h + s1 + ch + SHA512_K[i] + w[i];
        uint64_t s0 = sha512_rotr(a, 28) ^ sha512_rotr(a, 34) ^ sha512_rotr(a, 39);
        uint64_t maj = (a & b) ^ (a & c) ^ (b & c);
        uint64_t t2 = s0 + maj;
        h = g;
        g = f;
        f = e;
        e = d + t1;
        d = c;
        c = b;
        b = a;
        a = t1 + t2;
    }
    ctx->state[0] += a;
    ctx->state[1] += b;
    ctx->state[2] += c;
    ctx->state[3] += d;
    ctx->state[4] += e;
    ctx->state[5] += f;
    ctx->state[6] += g;
    ctx->state[7] += h;
}

static void sha512_update(Sha512Ctx *ctx, const uint8_t *data, size_t len)
{
    size_t index = static_cast<size_t>((ctx->count[0] >> 3) & 0x7f);
    ctx->count[0] += static_cast<uint64_t>(len) << 3;
    if (ctx->count[0] < static_cast<uint64_t>(len) << 3) {
        ctx->count[1]++;
    }
    size_t partLen = 128 - index;
    size_t i = 0;
    if (len >= partLen) {
        memcpy(ctx->buffer + index, data, partLen);
        sha512_transform(ctx, ctx->buffer);
        for (i = partLen; i + 127 < len; i += 128) {
            sha512_transform(ctx, data + i);
        }
        index = 0;
    }
    memcpy(ctx->buffer + index, data + i, len - i);
}

static void sha512_final(Sha512Ctx *ctx, uint8_t digest[64])
{
    static const uint8_t padding[128] = { 0x80 };
    uint8_t bits[16] = { 0 };
    for (int i = 0; i < 8; i++) {
        bits[i] = static_cast<uint8_t>((ctx->count[1] >> ((7 - i) * 8)) & 0xff);
    }
    for (int i = 0; i < 8; i++) {
        bits[8 + i] = static_cast<uint8_t>((ctx->count[0] >> ((7 - i) * 8)) & 0xff);
    }
    size_t index = static_cast<size_t>((ctx->count[0] >> 3) & 0x7f);
    size_t padLen = (index < 112) ? (112 - index) : (240 - index);
    sha512_update(ctx, padding, padLen);
    sha512_update(ctx, bits, 16);
    for (int i = 0; i < 8; i++) {
        for (int j = 0; j < 8; j++) {
            digest[i * 8 + j] = static_cast<uint8_t>((ctx->state[i] >> ((7 - j) * 8)) & 0xff);
        }
    }
}

std::vector<uint8_t> sha512_digest(const std::vector<uint8_t> &data)
{
    Sha512Ctx ctx;
    ctx.state[0] = 0x6a09e667f3bcc908ULL;
    ctx.state[1] = 0xbb67ae8584caa73bULL;
    ctx.state[2] = 0x3c6ef372fe94f82bULL;
    ctx.state[3] = 0xa54ff53a5f1d36f1ULL;
    ctx.state[4] = 0x510e527fade682d1ULL;
    ctx.state[5] = 0x9b05688c2b3e6c1fULL;
    ctx.state[6] = 0x1f83d9abfb41bd6bULL;
    ctx.state[7] = 0x5be0cd19137e2179ULL;
    ctx.count[0] = ctx.count[1] = 0;
    if (!data.empty()) {
        sha512_update(&ctx, data.data(), data.size());
    }
    std::vector<uint8_t> out(64);
    sha512_final(&ctx, out.data());
    return out;
}

std::vector<uint8_t> digest_for_type(const std::string &type, const std::vector<uint8_t> &data)
{
    if (type == "md5") {
        return md5_digest(data);
    }
    if (type == "sha1") {
        return sha1_digest(data);
    }
    if (type == "sha256") {
        return sha256_digest(data);
    }
    if (type == "sha512") {
        return sha512_digest(data);
    }
    return {};
}

std::vector<uint8_t> hmac_for(const std::string &hashName, const std::vector<uint8_t> &key,
    const std::vector<uint8_t> &data)
{
    size_t blockSize = 64;
    if (hashName == "sha512") {
        blockSize = 128;
    }
    std::vector<uint8_t> k = key;
    if (k.size() > blockSize) {
        k = digest_for_type(hashName, k);
    }
    if (k.size() < blockSize) {
        k.resize(blockSize, 0);
    }
    std::vector<uint8_t> ipad(blockSize);
    std::vector<uint8_t> opad(blockSize);
    for (size_t i = 0; i < blockSize; i++) {
        ipad[i] = k[i] ^ 0x36;
        opad[i] = k[i] ^ 0x5c;
    }
    std::vector<uint8_t> inner = ipad;
    inner.insert(inner.end(), data.begin(), data.end());
    std::vector<uint8_t> innerHash = digest_for_type(hashName, inner);
    std::vector<uint8_t> outer = opad;
    outer.insert(outer.end(), innerHash.begin(), innerHash.end());
    return digest_for_type(hashName, outer);
}

} // namespace

std::string venera_convert_message_json(const std::string &requestJson)
{
    const std::string type = extract_field_string(requestJson, "type");
    const bool isEncode = extract_field_bool(requestJson, "isEncode", false);
    const bool isString = extract_field_bool(requestJson, "isString", false);
    const std::vector<uint8_t> valueBytes = parse_field_bytes(requestJson, "value");

    if (type == "base64") {
        if (isEncode) {
            return "\"" + json_escape(base64_encode(valueBytes)) + "\"";
        }
        const std::string text = extract_field_string(requestJson, "value");
        return bytes_to_json_array(base64_decode(text));
    }

    if (type == "hmac") {
        std::string hashName = extract_field_string(requestJson, "hash");
        if (hashName.empty()) {
            hashName = "sha256";
        }
        const std::vector<uint8_t> keyBytes = parse_field_bytes(requestJson, "key");
        const std::vector<uint8_t> mac = hmac_for(hashName, keyBytes, valueBytes);
        if (mac.empty()) {
            return "null";
        }
        if (isString) {
            return "\"" + bytes_to_hex(mac.data(), mac.size()) + "\"";
        }
        return bytes_to_json_array(mac);
    }

    const std::vector<uint8_t> digest = digest_for_type(type, valueBytes);
    if (digest.empty()) {
        return "null";
    }
    if (isString) {
        return "\"" + bytes_to_hex(digest.data(), digest.size()) + "\"";
    }
    return bytes_to_json_array(digest);
}
