// Command-line access to the prefix checkpoint key derivation, so a shell test
// drives the header the candidate patch adds without a server, a model, or a
// device. The header is the whole subject: it is compiled out of the patch into
// a temporary directory and linked against this driver alone.

#include "server-prefix-checkpoint.h"

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>
#include <vector>

static int usage(const char * program) {
    fprintf(stderr, "usage: %s sha256 STRING\n", program);
    fprintf(stderr, "       %s tokens T0[,T1...]\n", program);
    fprintf(stderr, "       %s key MODEL TEMPLATE RUNTIME BUILD SYSTEM PREFIX N_TOKENS\n", program);
    return 2;
}

static std::vector<int32_t> parse_tokens(const char * text) {
    std::vector<int32_t> tokens;

    const char * cursor = text;
    while (*cursor != '\0') {
        char * end = nullptr;
        const long value = strtol(cursor, &end, 10);
        if (end == cursor) {
            break;
        }
        tokens.push_back((int32_t) value);
        cursor = (*end == ',') ? end + 1 : end;
    }

    return tokens;
}

int main(int argc, char ** argv) {
    if (argc < 2) {
        return usage(argv[0]);
    }

    const std::string mode = argv[1];

    if (mode == "sha256") {
        if (argc != 3) {
            return usage(argv[0]);
        }
        printf("%s\n", prefix_checkpoint_digest(std::string(argv[2])).c_str());
        return 0;
    }

    if (mode == "tokens") {
        if (argc != 3) {
            return usage(argv[0]);
        }
        const std::vector<int32_t> tokens = parse_tokens(argv[2]);
        printf("%s\n", prefix_checkpoint_token_digest(tokens.data(), tokens.size()).c_str());
        return 0;
    }

    if (mode == "key") {
        if (argc != 9) {
            return usage(argv[0]);
        }

        prefix_checkpoint_key_fields fields;

        fields.model_identity      = argv[2];
        fields.chat_template       = argv[3];
        fields.runtime_tuple       = argv[4];
        fields.build_identity      = argv[5];
        fields.system_span_digest  = argv[6];
        fields.prefix_token_digest = argv[7];
        fields.n_prefix_tokens     = (size_t) strtoul(argv[8], nullptr, 10);

        printf("%s\n", prefix_checkpoint_key(fields).c_str());
        return 0;
    }

    return usage(argv[0]);
}
