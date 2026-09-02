/* Sample the amdgpu clock state from open descriptors at a fixed period.
 *
 * sample-clock-sidecar.py opens five sysfs files, parses their text, and
 * formats one row inside every sample, so its per-sample cost carries three
 * open/read/close triples, the CPython interpreter, and a write through
 * buffered stdio. This broker moves that work out of the sample: every
 * descriptor is opened once at startup, each sample is a pread into a fixed
 * buffer followed by an integer parse into a preallocated ring of fixed-width
 * binary records, and the whole record is formatted from that ring after
 * SIGTERM. The fast path therefore allocates nothing, opens nothing, and
 * formats nothing, and the ring holds the run.
 *
 * The schedule is multirate because the sensor families move at different
 * rates against one token and cost different amounts to read. Every period
 * reads gpu_busy_percent; every tenth period reads the selected SCLK, MCLK,
 * and FCLK steps beside the die temperature; every hundredth reads
 * MemAvailable from /proc/meminfo and pswpin from /proc/vmstat, and every
 * hundredth also reads the one-minute load average from /proc/loadavg and
 * pages_sharing from /sys/kernel/mm/ksm. Period 0 reads every family, so the
 * first row carries a real reading in each column.
 *
 * The host channel is what places a clock step beside the machine state at
 * that instant: the calibration of 20260902T1302Z watched the selected
 * graphics clock fall from 1100 MHz to 800 MHz partway through an arm list,
 * and a reading of that fall is a reading of what else the host was doing.
 *
 * The DPM attributes sit on the tenth-period channel because reading them is
 * the expensive half of a sample and their state moves slower than the read.
 * pp_dpm_sclk, pp_dpm_mclk, and pp_dpm_fclk resolve through an SMU firmware
 * message that the amdgpu driver serializes against its own DPM work, which is
 * what put the Python sampler's mean sample cost at 0.82 ms with 32 of 1654
 * samples above 5 ms and two reads between 29 and 37 ms. The channel is every
 * tenth period rather than a wall-clock rate, so a shorter --period-ms
 * shortens it proportionally. At the 10 ms period the appliance measured the
 * cost at, it is the 100 ms read that costs the served decode 0.1 to 0.14%
 * against the 1.0 to 1.4% a per-period read cost, inside the 0.65% the sidecar
 * contract bounds, and DPM state changes on a 100 ms scale so the clock record
 * survives the reduction. The `# sample_rates` header line carries the
 * interval the run actually used.
 *
 * The emitted record is byte-compatible with sample-clock-sidecar.py:
 * validate-clock-sidecar.py reads the same header keys, the same seven
 * columns, and the same footer keys. The four slow columns hold their own
 * places, so a row between two reads of a channel repeats that channel's last
 * reading and the row shape is unchanged. MemAvailable and pswpin hold no
 * column, so they are emitted as their own `# meminfo` lines interleaved with
 * the rows at their own sample instants, and the load average and the KSM
 * sharing count are emitted the same way on `# host` lines; read_record in the validator sends
 * every `#` line other than the footer to the header, which leaves the row
 * count and the column arity alone. A `# sample_rates` header line names the
 * period each surface is read at, so a reader places a repeated value against
 * the channel that produced it.
 *
 * --control names a FIFO carrying one command per line. PAUSE parks the
 * sampler in a poll wait with every descriptor still open, which is the
 * measured state a census arm needs when the sidecar must contribute no reads;
 * RESUME leaves that wait and restarts the deadline at now + period, so a
 * resumed run emits no burst of expired deadlines. MARK name places
 * `# mark name=<value> monotonic_ns=<now>` in the record in sequence with the
 * samples, and PAUSE and RESUME place their own marks at the instants they
 * enter and leave the wait, so the paused span is bounded by the record's own
 * timestamps rather than by the caller's wall clock.
 *
 * usage: telemetry-broker OUTPUT_TSV --period-ms N --cpu LIST
 *        --drm-device DIR [--hwmon DIR] [--control FIFO]
 */
#define _GNU_SOURCE

#include <errno.h>
#include <fcntl.h>
#include <inttypes.h>
#include <limits.h>
#include <poll.h>
#include <sched.h>
#include <signal.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/resource.h>
#include <sys/stat.h>
#include <time.h>
#include <unistd.h>

/* 262144 records at 40 bytes is a 10 MiB ring, which covers 21.8 minutes at a
 * 5 ms period and 43.7 minutes at 10 ms. A census arm is minutes long, so the
 * ring holds the run and the fast path never reaches an allocator. */
#define SAMPLE_CAPACITY 262144u
#define MARK_CAPACITY 4096u
#define MEMORY_CAPACITY 4096u
#define HOST_CAPACITY 4096u
#define MARK_NAME_BYTES 32u
/* "0.52" and its neighbours; a load average printed wider than this is
 * truncated at the field rather than overrunning it. */
#define LOAD_TEXT_BYTES 16u
#define SYSFS_BUFFER_BYTES 4096u
#define PROC_BUFFER_BYTES 16384u
#define CONTROL_BUFFER_BYTES 512u
/* The DPM attributes and the die temperature share the tenth-period channel,
 * which is 100 ms at the appliance's 10 ms period. */
#define DPM_PERIOD_MULTIPLE 10u
#define TEMPERATURE_PERIOD_MULTIPLE 10u
#define MEMORY_PERIOD_MULTIPLE 100u
/* The host channel shares that hundredth period, which is 1 s at the
 * appliance's 10 ms period. */
#define HOST_PERIOD_MULTIPLE 100u

#define UNAVAILABLE_SCLK 0x01u
#define UNAVAILABLE_MCLK 0x02u
#define UNAVAILABLE_FCLK 0x04u
#define UNAVAILABLE_BUSY 0x08u
#define UNAVAILABLE_TEMPERATURE 0x10u

#define NANOSECONDS_PER_SECOND INT64_C(1000000000)

/* A sensor value of -1 is the unavailable reading; every real surface here is
 * a non-negative integer. */
#define VALUE_UNAVAILABLE INT32_C(-1)

struct sample_record {
    uint64_t monotonic_ns;
    int32_t sclk_mhz;
    int32_t mclk_mhz;
    int32_t fclk_mhz;
    int32_t busy_percent;
    int32_t temperature_millidegrees;
    uint32_t cost_ns;
    uint32_t unavailable_flags;
};

_Static_assert(sizeof(struct sample_record) == 40,
               "the sample record is the ring's fixed width");

struct mark_record {
    uint64_t monotonic_ns;
    char name[MARK_NAME_BYTES];
};

struct memory_record {
    uint64_t monotonic_ns;
    int64_t memory_available_kb;
    int64_t pswpin;
};

struct host_record {
    uint64_t monotonic_ns;
    int64_t ksm_pages_sharing;
    char load1[LOAD_TEXT_BYTES];
};

struct broker {
    int sclk_fd;
    int mclk_fd;
    int fclk_fd;
    int busy_fd;
    int temperature_fd;
    int meminfo_fd;
    int vmstat_fd;
    int loadavg_fd;
    int ksm_sharing_fd;
    int control_read_fd;
    int control_keep_fd;

    struct sample_record *samples;
    uint64_t sample_count;
    bool ring_full_reported;

    /* The every-period surfaces alone, so the reported fast-path cost excludes
     * the tenth-period temperature read and the hundredth-period /proc pair. */
    uint64_t fast_path_samples;
    uint64_t fast_path_cost_total;
    uint64_t fast_path_cost_max;

    struct mark_record *marks;
    uint64_t mark_count;
    uint64_t marks_rejected;

    struct memory_record *memory;
    uint64_t memory_count;

    struct host_record *host;
    uint64_t host_count;

    char sysfs_buffer[SYSFS_BUFFER_BYTES];
    char proc_buffer[PROC_BUFFER_BYTES];
    char control_buffer[CONTROL_BUFFER_BYTES];
    size_t control_length;

    bool paused;
    bool resume_requested;
};

static volatile sig_atomic_t stop_requested;

static void handle_signal(int signal_number)
{
    (void)signal_number;
    stop_requested = 1;
}

static uint64_t monotonic_nanoseconds(void)
{
    struct timespec instant = {0, 0};

    if (clock_gettime(CLOCK_MONOTONIC, &instant) != 0) {
        perror("clock_gettime(CLOCK_MONOTONIC)");
        exit(EXIT_FAILURE);
    }
    return (uint64_t)instant.tv_sec * (uint64_t)NANOSECONDS_PER_SECOND +
           (uint64_t)instant.tv_nsec;
}

static void usage(const char *program)
{
    fprintf(stderr,
            "usage: %s OUTPUT_TSV --period-ms N --cpu LIST"
            " --drm-device DIR [--hwmon DIR] [--control FIFO]\n",
            program);
    exit(2);
}

/* Reading */

static ssize_t read_snapshot(int descriptor, char *buffer, size_t capacity)
{
    ssize_t count;

    if (descriptor < 0) {
        return -1;
    }
    count = pread(descriptor, buffer, capacity - 1, 0);
    if (count < 0) {
        return -1;
    }
    buffer[count] = '\0';
    return count;
}

static int32_t parse_leading_integer(const char *text, size_t length)
{
    int64_t value = 0;
    size_t index = 0;

    if (length == 0 || text[0] < '0' || text[0] > '9') {
        return VALUE_UNAVAILABLE;
    }
    while (index < length && text[index] >= '0' && text[index] <= '9') {
        value = value * 10 + (text[index] - '0');
        if (value > INT32_MAX) {
            return VALUE_UNAVAILABLE;
        }
        index++;
    }
    return (int32_t)value;
}

/* The DPM surfaces print one line per step and star the selected one, as in
 * "1: 933Mhz *". The value is the second whitespace-separated token, which is
 * the token sample-clock-sidecar.py takes, so a step index never reads as a
 * frequency. A file carrying no star and an empty file both read unavailable,
 * which is what pp_dpm_fclk reports on the SMU10 path. */
static int32_t parse_selected_step(const char *text)
{
    const char *line = text;

    while (*line != '\0') {
        const char *newline = strchr(line, '\n');
        size_t length = (newline != NULL) ? (size_t)(newline - line) : strlen(line);
        if (memchr(line, '*', length) != NULL) {
            const char *cursor = line;
            const char *limit = line + length;
            size_t token_index = 0;

            while (cursor < limit) {
                const char *token_begin;

                while (cursor < limit && (*cursor == ' ' || *cursor == '\t')) {
                    cursor++;
                }
                token_begin = cursor;
                while (cursor < limit && *cursor != ' ' && *cursor != '\t') {
                    cursor++;
                }
                if (cursor == token_begin) {
                    break;
                }
                if (token_index == 1) {
                    return parse_leading_integer(token_begin,
                                                 (size_t)(cursor - token_begin));
                }
                token_index++;
            }
            return VALUE_UNAVAILABLE;
        }
        if (newline == NULL) {
            break;
        }
        line = newline + 1;
    }
    return VALUE_UNAVAILABLE;
}

static int32_t parse_scalar(const char *text)
{
    const char *cursor = text;

    while (*cursor == ' ' || *cursor == '\t' || *cursor == '\n') {
        cursor++;
    }
    return parse_leading_integer(cursor, strlen(cursor));
}

static int64_t parse_leading_integer64(const char *text, size_t length)
{
    int64_t value = 0;
    size_t index = 0;

    if (length == 0 || text[0] < '0' || text[0] > '9') {
        return INT64_C(-1);
    }
    while (index < length && text[index] >= '0' && text[index] <= '9') {
        if (value > (INT64_MAX - (text[index] - '0')) / 10) {
            return INT64_C(-1);
        }
        value = value * 10 + (text[index] - '0');
        index++;
    }
    return value;
}

/* /proc/meminfo prints "MemAvailable:    1234 kB" and /proc/vmstat prints
 * "pswpin 0", so one line-start match followed by the first digit run reads
 * both. The 64-bit parse carries a kibibyte count and a swap-in counter past
 * the int32 ceiling the sensor columns sit under. */
static int64_t parse_proc_field(const char *text, const char *key)
{
    size_t key_length = strlen(key);
    const char *line = text;

    while (*line != '\0') {
        const char *newline = strchr(line, '\n');
        size_t length = (newline != NULL) ? (size_t)(newline - line) : strlen(line);

        if (length > key_length && memcmp(line, key, key_length) == 0 &&
            (line[key_length] == ':' || line[key_length] == ' ' ||
             line[key_length] == '\t')) {
            size_t index = key_length;

            while (index < length && (line[index] < '0' || line[index] > '9')) {
                index++;
            }
            if (index < length) {
                return parse_leading_integer64(line + index, length - index);
            }
            return INT64_C(-1);
        }
        if (newline == NULL) {
            break;
        }
        line = newline + 1;
    }
    return INT64_C(-1);
}

/* /proc/loadavg opens on the one-minute average, "0.52 0.58 0.59 1/512 8123",
 * which carries a decimal point and no key, so the leading run of digits and
 * points is copied out as text rather than parsed to an integer. A first
 * character outside that set is a surface this reader cannot state. */
static void parse_load_average(const char *text, char *buffer, size_t capacity)
{
    size_t index = 0;

    if (text[0] < '0' || text[0] > '9') {
        snprintf(buffer, capacity, "unavailable");
        return;
    }
    while (index + 1 < capacity &&
           ((text[index] >= '0' && text[index] <= '9') || text[index] == '.')) {
        buffer[index] = text[index];
        index++;
    }
    buffer[index] = '\0';
}

/* Marks */

static bool mark_name_is_admissible(const char *name)
{
    size_t index;

    if (name[0] == '\0' || strlen(name) >= MARK_NAME_BYTES) {
        return false;
    }
    /* The validator merges every `#` line into one key=value map, so a mark
     * name carrying whitespace or an equals sign would inject a header key. */
    for (index = 0; name[index] != '\0'; index++) {
        char character = name[index];
        bool admissible = (character >= 'A' && character <= 'Z') ||
                          (character >= 'a' && character <= 'z') ||
                          (character >= '0' && character <= '9') ||
                          character == '_' || character == '-' ||
                          character == '.';
        if (!admissible) {
            return false;
        }
    }
    return true;
}

static void record_mark(struct broker *broker, const char *name, uint64_t instant)
{
    if (!mark_name_is_admissible(name) || broker->mark_count >= MARK_CAPACITY) {
        broker->marks_rejected++;
        return;
    }
    broker->marks[broker->mark_count].monotonic_ns = instant;
    strncpy(broker->marks[broker->mark_count].name, name, MARK_NAME_BYTES - 1);
    broker->marks[broker->mark_count].name[MARK_NAME_BYTES - 1] = '\0';
    broker->mark_count++;
}

/* Control */

static void apply_command(struct broker *broker, char *line)
{
    uint64_t instant = monotonic_nanoseconds();
    char *cursor = line;
    char *end;

    while (*cursor == ' ' || *cursor == '\t' || *cursor == '\r') {
        cursor++;
    }
    end = cursor + strlen(cursor);
    while (end > cursor && (end[-1] == ' ' || end[-1] == '\t' || end[-1] == '\r')) {
        end--;
    }
    *end = '\0';

    if (*cursor == '\0') {
        return;
    }
    if (strcmp(cursor, "PAUSE") == 0) {
        if (!broker->paused) {
            record_mark(broker, "PAUSE", instant);
            broker->paused = true;
        }
        return;
    }
    if (strcmp(cursor, "RESUME") == 0) {
        if (broker->paused) {
            record_mark(broker, "RESUME", instant);
            broker->paused = false;
            broker->resume_requested = true;
        }
        return;
    }
    if (strncmp(cursor, "MARK ", 5) == 0) {
        char *name = cursor + 5;

        while (*name == ' ' || *name == '\t') {
            name++;
        }
        record_mark(broker, name, instant);
        return;
    }
    broker->marks_rejected++;
}

static void consume_control_lines(struct broker *broker)
{
    size_t consumed = 0;

    for (;;) {
        char *newline = memchr(broker->control_buffer + consumed, '\n',
                               broker->control_length - consumed);
        if (newline == NULL) {
            break;
        }
        *newline = '\0';
        apply_command(broker, broker->control_buffer + consumed);
        consumed = (size_t)(newline - broker->control_buffer) + 1;
    }
    if (consumed > 0) {
        memmove(broker->control_buffer, broker->control_buffer + consumed,
                broker->control_length - consumed);
        broker->control_length -= consumed;
    }
    /* A line longer than the buffer is a command this broker does not carry,
     * so the partial bytes are dropped rather than joined to the next read. */
    if (broker->control_length + 1 >= CONTROL_BUFFER_BYTES) {
        broker->control_length = 0;
        broker->marks_rejected++;
    }
}

static void drain_control(struct broker *broker)
{
    if (broker->control_read_fd < 0) {
        return;
    }
    for (;;) {
        ssize_t count = read(broker->control_read_fd,
                             broker->control_buffer + broker->control_length,
                             CONTROL_BUFFER_BYTES - 1 - broker->control_length);
        if (count <= 0) {
            break;
        }
        broker->control_length += (size_t)count;
        consume_control_lines(broker);
        if (broker->control_length + 1 >= CONTROL_BUFFER_BYTES) {
            break;
        }
    }
    consume_control_lines(broker);
}

static void wait_while_paused(struct broker *broker)
{
    while (broker->paused && stop_requested == 0) {
        struct pollfd descriptor;
        int ready;

        descriptor.fd = broker->control_read_fd;
        descriptor.events = POLLIN;
        descriptor.revents = 0;
        ready = poll(&descriptor, 1, 1000);
        if (ready > 0) {
            drain_control(broker);
        } else if (ready < 0 && errno != EINTR) {
            break;
        }
    }
}

/* Drain */

static const char *format_value(int32_t value, char *buffer, size_t capacity)
{
    if (value == VALUE_UNAVAILABLE) {
        return "unavailable";
    }
    snprintf(buffer, capacity, "%" PRId32, value);
    return buffer;
}

static int write_record(const struct broker *broker, const char *output_path,
                        uint64_t period_ns, const char *drm_device,
                        const char *hwmon, const char *cpu_affinity,
                        int nice_value)
{
    FILE *out = fopen(output_path, "w");
    uint64_t sample_index = 0;
    uint64_t mark_index = 0;
    uint64_t memory_index = 0;
    uint64_t host_index = 0;
    uint64_t cost_total = 0;
    uint64_t cost_max = 0;
    uint64_t unavailable_rows = 0;
    uint64_t first_ns = 0;
    uint64_t last_ns = 0;
    uint64_t achieved_ns = 0;
    uint64_t mean_cost_ns = 0;

    if (out == NULL) {
        fprintf(stderr, "failed to write output: %s\n", strerror(errno));
        return 2;
    }

    fprintf(out, "# clock=CLOCK_MONOTONIC period_ns=%" PRIu64 " drm_device=%s hwmon=%s\n",
            period_ns, drm_device, hwmon);
    /* Every column is emitted on every row, and a column read on a slower
     * channel repeats its last reading between reads, so this line is what
     * separates a repeated value from a re-measured one. The keys are distinct
     * from the three the validator reads out of the merged header. */
    fprintf(out, "# sample_rates: gpu_busy_percent_period_ns=%" PRIu64
                 " pp_dpm_period_ns=%" PRIu64 " temp1_input_period_ns=%" PRIu64
                 " meminfo_period_ns=%" PRIu64 " vmstat_period_ns=%" PRIu64
                 " host_period_ns=%" PRIu64 "\n",
            period_ns, period_ns * DPM_PERIOD_MULTIPLE,
            period_ns * TEMPERATURE_PERIOD_MULTIPLE,
            period_ns * MEMORY_PERIOD_MULTIPLE,
            period_ns * MEMORY_PERIOD_MULTIPLE,
            period_ns * HOST_PERIOD_MULTIPLE);
    fprintf(out, "# interpretation: pp_dpm_sclk_selected_mhz is the selected graphics clock step;"
                 " pp_dpm_mclk_surface_mhz is the pp_dpm_mclk sysfs surface, which on SMU10 is a"
                 " fabric-clock state rather than the trained DRAM speed;"
                 " pp_dpm_fclk_surface_mhz is the pp_dpm_fclk sysfs surface\n");
    fprintf(out, "# sampler_pid=%d nice=%d cpu_affinity=%s\n",
            (int)getpid(), nice_value, cpu_affinity);
    fprintf(out, "monotonic_ns\tpp_dpm_sclk_selected_mhz\tpp_dpm_mclk_surface_mhz"
                 "\tpp_dpm_fclk_surface_mhz\tgpu_busy_percent\ttemp1_millidegrees"
                 "\tsample_cost_ns\n");

    /* Four arrays each hold their own instants in order, so one merge places
     * every mark, memory reading, and host reading between the rows it fell
     * between. A tie emits the annotation ahead of the row, since a slow-rate
     * reading is taken inside the sample that carries its instant. */
    while (sample_index < broker->sample_count || mark_index < broker->mark_count ||
           memory_index < broker->memory_count || host_index < broker->host_count) {
        uint64_t sample_ns = (sample_index < broker->sample_count)
                                 ? broker->samples[sample_index].monotonic_ns
                                 : UINT64_MAX;
        uint64_t mark_ns = (mark_index < broker->mark_count)
                               ? broker->marks[mark_index].monotonic_ns
                               : UINT64_MAX;
        uint64_t memory_ns = (memory_index < broker->memory_count)
                                 ? broker->memory[memory_index].monotonic_ns
                                 : UINT64_MAX;
        uint64_t host_ns = (host_index < broker->host_count)
                               ? broker->host[host_index].monotonic_ns
                               : UINT64_MAX;

        if (mark_ns <= sample_ns && mark_ns <= memory_ns && mark_ns <= host_ns) {
            fprintf(out, "# mark name=%s monotonic_ns=%" PRIu64 "\n",
                    broker->marks[mark_index].name, mark_ns);
            mark_index++;
            continue;
        }
        if (memory_ns <= sample_ns && memory_ns <= host_ns) {
            const struct memory_record *record = &broker->memory[memory_index];
            char available[32];
            char pswpin[32];

            if (record->memory_available_kb < 0) {
                snprintf(available, sizeof(available), "unavailable");
            } else {
                snprintf(available, sizeof(available), "%" PRId64,
                         record->memory_available_kb);
            }
            if (record->pswpin < 0) {
                snprintf(pswpin, sizeof(pswpin), "unavailable");
            } else {
                snprintf(pswpin, sizeof(pswpin), "%" PRId64, record->pswpin);
            }
            fprintf(out, "# meminfo monotonic_ns=%" PRIu64 " mem_available_kb=%s pswpin=%s\n",
                    memory_ns, available, pswpin);
            memory_index++;
            continue;
        }
        if (host_ns <= sample_ns) {
            const struct host_record *record = &broker->host[host_index];
            char sharing[32];

            if (record->ksm_pages_sharing < 0) {
                snprintf(sharing, sizeof(sharing), "unavailable");
            } else {
                snprintf(sharing, sizeof(sharing), "%" PRId64,
                         record->ksm_pages_sharing);
            }
            fprintf(out, "# host monotonic_ns=%" PRIu64 " load1=%s ksm_pages_sharing=%s\n",
                    host_ns, record->load1, sharing);
            host_index++;
            continue;
        }
        {
            const struct sample_record *sample = &broker->samples[sample_index];
            char sclk[32];
            char mclk[32];
            char fclk[32];
            char busy[32];
            char temperature[32];

            fprintf(out, "%" PRIu64 "\t%s\t%s\t%s\t%s\t%s\t%" PRIu32 "\n",
                    sample->monotonic_ns,
                    format_value(sample->sclk_mhz, sclk, sizeof(sclk)),
                    format_value(sample->mclk_mhz, mclk, sizeof(mclk)),
                    format_value(sample->fclk_mhz, fclk, sizeof(fclk)),
                    format_value(sample->busy_percent, busy, sizeof(busy)),
                    format_value(sample->temperature_millidegrees, temperature,
                                 sizeof(temperature)),
                    sample->cost_ns);
            if (sample->unavailable_flags != 0) {
                unavailable_rows++;
            }
            cost_total += sample->cost_ns;
            if (sample->cost_ns > cost_max) {
                cost_max = sample->cost_ns;
            }
            if (sample_index == 0) {
                first_ns = sample->monotonic_ns;
            }
            last_ns = sample->monotonic_ns;
            sample_index++;
        }
    }

    /* The achieved period is the run mean over the sample span, the figure
     * sample-clock-sidecar.py declares, so a paused span widens it exactly as
     * a stalled sampler would. The adjacent-gap distribution is what separates
     * the two, and validate-clock-sidecar.py reads it from the rows. */
    if (broker->sample_count >= 2) {
        achieved_ns = (last_ns - first_ns) / (broker->sample_count - 1);
    }
    if (broker->sample_count > 0) {
        mean_cost_ns = cost_total / broker->sample_count;
    }

    fprintf(out, "# samples=%" PRIu64 " achieved_period_ns=%" PRIu64
                 " mean_sample_cost_ns=%" PRIu64 " max_sample_cost_ns=%" PRIu64
                 " samples_with_unavailable_sensor=%" PRIu64
                 " first_sample_ns=%" PRIu64 " last_sample_ns=%" PRIu64 "\n",
            broker->sample_count, achieved_ns, mean_cost_ns, cost_max,
            unavailable_rows, first_ns, last_ns);

    if (fclose(out) != 0) {
        fprintf(stderr, "failed to close output: %s\n", strerror(errno));
        return 2;
    }

    /* The footer keeps sample-clock-sidecar.py's meaning, the mean and maximum
     * over every sample including the tenth- and hundredth-period reads. The
     * fast-path group beside it covers the samples that read the every-period
     * surface alone, which is the cost the 50 us target names, and
     * fast_path_surfaces states which surface that is. */
    fprintf(stderr, "telemetry_broker=drained samples=%" PRIu64
                    " marks=%" PRIu64 " memory_readings=%" PRIu64
                    " host_readings=%" PRIu64
                    " mean_sample_cost_ns=%" PRIu64 " max_sample_cost_ns=%" PRIu64
                    " fast_path_surfaces=gpu_busy_percent"
                    " fast_path_samples=%" PRIu64
                    " fast_path_mean_cost_ns=%" PRIu64
                    " fast_path_max_cost_ns=%" PRIu64
                    " marks_rejected=%" PRIu64 " ring_full=%d\n",
            broker->sample_count, broker->mark_count, broker->memory_count,
            broker->host_count,
            mean_cost_ns, cost_max, broker->fast_path_samples,
            (broker->fast_path_samples > 0)
                ? broker->fast_path_cost_total / broker->fast_path_samples
                : UINT64_C(0),
            broker->fast_path_cost_max, broker->marks_rejected,
            broker->ring_full_reported ? 1 : 0);
    return 0;
}

/* Startup */

static int open_surface(const char *directory, const char *leaf)
{
    char path[PATH_MAX];

    if (directory == NULL) {
        return -1;
    }
    snprintf(path, sizeof(path), "%s/%s", directory, leaf);
    return open(path, O_RDONLY | O_CLOEXEC);
}

static void build_affinity_string(char *buffer, size_t capacity)
{
    cpu_set_t affinity;
    size_t length = 0;
    int cpu;

    buffer[0] = '\0';
    CPU_ZERO(&affinity);
    if (sched_getaffinity(0, sizeof(affinity), &affinity) != 0) {
        return;
    }
    for (cpu = 0; cpu < CPU_SETSIZE; cpu++) {
        if (!CPU_ISSET(cpu, &affinity)) {
            continue;
        }
        length += (size_t)snprintf(buffer + length, capacity - length, "%s%d",
                                   (length > 0) ? "," : "", cpu);
        if (length + 8 >= capacity) {
            break;
        }
    }
}

static int apply_affinity(const char *list)
{
    cpu_set_t affinity;
    const char *cursor = list;

    CPU_ZERO(&affinity);
    while (*cursor != '\0') {
        char *end = NULL;
        long value;

        if (*cursor == ',') {
            cursor++;
            continue;
        }
        errno = 0;
        value = strtol(cursor, &end, 10);
        if (end == cursor || errno != 0 || value < 0 || value >= CPU_SETSIZE) {
            fprintf(stderr, "cannot read CPU list: %s\n", list);
            return 2;
        }
        CPU_SET((int)value, &affinity);
        cursor = end;
    }
    if (sched_setaffinity(0, sizeof(affinity), &affinity) != 0) {
        fprintf(stderr, "cannot set CPU affinity to %s: %s\n", list, strerror(errno));
        return 2;
    }
    return 0;
}

int main(int argc, char **argv)
{
    const char *output_path = NULL;
    const char *drm_device = NULL;
    const char *hwmon = NULL;
    const char *control_path = NULL;
    const char *cpu_list = NULL;
    double period_ms = 5.0;
    /* Every measurement process on the appliance runs at nice 19, so the
     * level is a constant rather than an argument a caller could lower. */
    const long nice_target = 19;
    uint64_t period_ns;
    uint64_t tick = 0;
    struct broker broker;
    struct sigaction action;
    struct timespec deadline;
    char affinity_string[512];
    int applied_nice;
    int argument;
    int status;

    for (argument = 1; argument < argc; argument++) {
        const char *option = argv[argument];

        if (option[0] != '-') {
            if (output_path != NULL) {
                usage(argv[0]);
            }
            output_path = option;
            continue;
        }
        if (argument + 1 >= argc) {
            usage(argv[0]);
        }
        argument++;
        if (strcmp(option, "--period-ms") == 0) {
            char *end = NULL;
            errno = 0;
            period_ms = strtod(argv[argument], &end);
            if (end == argv[argument] || errno != 0 || !(period_ms > 0.0)) {
                fprintf(stderr, "period must be positive\n");
                return 2;
            }
        } else if (strcmp(option, "--cpu") == 0) {
            cpu_list = argv[argument];
        } else if (strcmp(option, "--drm-device") == 0) {
            drm_device = argv[argument];
        } else if (strcmp(option, "--hwmon") == 0) {
            hwmon = argv[argument];
        } else if (strcmp(option, "--control") == 0) {
            control_path = argv[argument];
        } else {
            usage(argv[0]);
        }
    }
    if (output_path == NULL || drm_device == NULL) {
        usage(argv[0]);
    }

    period_ns = (uint64_t)(period_ms * 1000000.0 + 0.5);
    if (period_ns == 0) {
        fprintf(stderr, "period must be positive\n");
        return 2;
    }

    /* setpriority sets the absolute niceness, so the sampler reaches the
     * requested level independently of the shell that started it. */
    if (setpriority(PRIO_PROCESS, 0, (int)nice_target) != 0) {
        fprintf(stderr, "cannot reach nice %ld: %s\n", nice_target, strerror(errno));
        return 2;
    }
    errno = 0;
    applied_nice = getpriority(PRIO_PROCESS, 0);
    if (applied_nice == -1 && errno != 0) {
        fprintf(stderr, "cannot read the applied nice level: %s\n", strerror(errno));
        return 2;
    }

    if (cpu_list != NULL) {
        status = apply_affinity(cpu_list);
        if (status != 0) {
            return status;
        }
    }
    build_affinity_string(affinity_string, sizeof(affinity_string));

    memset(&broker, 0, sizeof(broker));
    broker.samples = calloc(SAMPLE_CAPACITY, sizeof(*broker.samples));
    broker.marks = calloc(MARK_CAPACITY, sizeof(*broker.marks));
    broker.memory = calloc(MEMORY_CAPACITY, sizeof(*broker.memory));
    broker.host = calloc(HOST_CAPACITY, sizeof(*broker.host));
    if (broker.samples == NULL || broker.marks == NULL || broker.memory == NULL ||
        broker.host == NULL) {
        fprintf(stderr, "cannot allocate the sample ring\n");
        return 2;
    }
    /* calloc leaves the ring unfaulted, so the first write to every page would
     * land inside a sample. Touching it here moves that cost to startup and
     * mlockall keeps it resident where the privilege allows it. */
    memset(broker.samples, 0, (size_t)SAMPLE_CAPACITY * sizeof(*broker.samples));
    memset(broker.marks, 0, (size_t)MARK_CAPACITY * sizeof(*broker.marks));
    memset(broker.memory, 0, (size_t)MEMORY_CAPACITY * sizeof(*broker.memory));
    memset(broker.host, 0, (size_t)HOST_CAPACITY * sizeof(*broker.host));
    (void)mlockall(MCL_CURRENT | MCL_FUTURE);

    broker.sclk_fd = open_surface(drm_device, "pp_dpm_sclk");
    broker.mclk_fd = open_surface(drm_device, "pp_dpm_mclk");
    broker.fclk_fd = open_surface(drm_device, "pp_dpm_fclk");
    broker.busy_fd = open_surface(drm_device, "gpu_busy_percent");
    broker.temperature_fd = open_surface(hwmon, "temp1_input");
    broker.meminfo_fd = open("/proc/meminfo", O_RDONLY | O_CLOEXEC);
    broker.vmstat_fd = open("/proc/vmstat", O_RDONLY | O_CLOEXEC);
    broker.loadavg_fd = open("/proc/loadavg", O_RDONLY | O_CLOEXEC);
    /* KSM is a kernel build option, so a host carrying no pages_sharing
     * attribute reports the column unavailable on every host line. */
    broker.ksm_sharing_fd = open("/sys/kernel/mm/ksm/pages_sharing",
                                 O_RDONLY | O_CLOEXEC);
    broker.control_read_fd = -1;
    broker.control_keep_fd = -1;

    if (control_path != NULL) {
        broker.control_read_fd = open(control_path, O_RDONLY | O_NONBLOCK | O_CLOEXEC);
        if (broker.control_read_fd < 0) {
            fprintf(stderr, "cannot open the control FIFO %s: %s\n", control_path,
                    strerror(errno));
            return 2;
        }
        /* Each caller writes one line and closes, so a resident writer of the
         * broker's own keeps poll from reporting POLLHUP between commands. */
        broker.control_keep_fd = open(control_path, O_WRONLY | O_NONBLOCK | O_CLOEXEC);
        if (broker.control_keep_fd < 0) {
            fprintf(stderr, "cannot hold the control FIFO %s open: %s\n", control_path,
                    strerror(errno));
            return 2;
        }
    }

    memset(&action, 0, sizeof(action));
    action.sa_handler = handle_signal;
    sigemptyset(&action.sa_mask);
    /* SA_RESTART stays off so a signal ends the paused poll wait and the
     * absolute clock_nanosleep rather than resuming them. */
    action.sa_flags = 0;
    if (sigaction(SIGTERM, &action, NULL) != 0 ||
        sigaction(SIGINT, &action, NULL) != 0) {
        fprintf(stderr, "cannot install the termination handler: %s\n", strerror(errno));
        return 2;
    }

    fprintf(stderr, "telemetry_broker=ready pid=%d period_ns=%" PRIu64
                    " nice=%d cpu_affinity=%s ring_samples=%u ring_bytes=%zu\n",
            (int)getpid(), period_ns, applied_nice, affinity_string,
            (unsigned)SAMPLE_CAPACITY,
            (size_t)SAMPLE_CAPACITY * sizeof(struct sample_record));
    fflush(stderr);

    {
        uint64_t now = monotonic_nanoseconds();
        deadline.tv_sec = (time_t)(now / (uint64_t)NANOSECONDS_PER_SECOND);
        deadline.tv_nsec = (long)(now % (uint64_t)NANOSECONDS_PER_SECOND);
    }

    {
        int32_t last_temperature = VALUE_UNAVAILABLE;
        int32_t last_sclk = VALUE_UNAVAILABLE;
        int32_t last_mclk = VALUE_UNAVAILABLE;
        int32_t last_fclk = VALUE_UNAVAILABLE;

        while (stop_requested == 0) {
            uint64_t begin;
            uint64_t end;
            uint32_t flags = 0;
            int32_t busy;
            int64_t memory_available = INT64_C(-1);
            int64_t pswpin = INT64_C(-1);
            bool memory_read = false;
            int64_t ksm_pages_sharing = INT64_C(-1);
            char load_average[LOAD_TEXT_BYTES];
            bool host_read = false;

            begin = monotonic_nanoseconds();

            busy = (read_snapshot(broker.busy_fd, broker.sysfs_buffer,
                                  SYSFS_BUFFER_BYTES) < 0)
                       ? VALUE_UNAVAILABLE
                       : parse_scalar(broker.sysfs_buffer);

            if (tick % DPM_PERIOD_MULTIPLE == 0) {
                last_sclk = (read_snapshot(broker.sclk_fd, broker.sysfs_buffer,
                                           SYSFS_BUFFER_BYTES) < 0)
                                ? VALUE_UNAVAILABLE
                                : parse_selected_step(broker.sysfs_buffer);
                last_mclk = (read_snapshot(broker.mclk_fd, broker.sysfs_buffer,
                                           SYSFS_BUFFER_BYTES) < 0)
                                ? VALUE_UNAVAILABLE
                                : parse_selected_step(broker.sysfs_buffer);
                last_fclk = (read_snapshot(broker.fclk_fd, broker.sysfs_buffer,
                                           SYSFS_BUFFER_BYTES) < 0)
                                ? VALUE_UNAVAILABLE
                                : parse_selected_step(broker.sysfs_buffer);
            }

            if (tick % TEMPERATURE_PERIOD_MULTIPLE == 0) {
                last_temperature = (read_snapshot(broker.temperature_fd,
                                                  broker.sysfs_buffer,
                                                  SYSFS_BUFFER_BYTES) < 0)
                                       ? VALUE_UNAVAILABLE
                                       : parse_scalar(broker.sysfs_buffer);
            }

            if (tick % MEMORY_PERIOD_MULTIPLE == 0) {
                if (read_snapshot(broker.meminfo_fd, broker.proc_buffer,
                                  PROC_BUFFER_BYTES) >= 0) {
                    memory_available = parse_proc_field(broker.proc_buffer,
                                                        "MemAvailable");
                }
                if (read_snapshot(broker.vmstat_fd, broker.proc_buffer,
                                  PROC_BUFFER_BYTES) >= 0) {
                    pswpin = parse_proc_field(broker.proc_buffer, "pswpin");
                }
                memory_read = true;
            }

            if (tick % HOST_PERIOD_MULTIPLE == 0) {
                snprintf(load_average, sizeof(load_average), "unavailable");
                if (read_snapshot(broker.loadavg_fd, broker.proc_buffer,
                                  PROC_BUFFER_BYTES) >= 0) {
                    parse_load_average(broker.proc_buffer, load_average,
                                       sizeof(load_average));
                }
                if (read_snapshot(broker.ksm_sharing_fd, broker.proc_buffer,
                                  PROC_BUFFER_BYTES) >= 0) {
                    ksm_pages_sharing = parse_leading_integer64(
                        broker.proc_buffer, strlen(broker.proc_buffer));
                }
                host_read = true;
            }

            end = monotonic_nanoseconds();

            if (last_sclk == VALUE_UNAVAILABLE) {
                flags |= UNAVAILABLE_SCLK;
            }
            if (last_mclk == VALUE_UNAVAILABLE) {
                flags |= UNAVAILABLE_MCLK;
            }
            if (last_fclk == VALUE_UNAVAILABLE) {
                flags |= UNAVAILABLE_FCLK;
            }
            if (busy == VALUE_UNAVAILABLE) {
                flags |= UNAVAILABLE_BUSY;
            }
            if (last_temperature == VALUE_UNAVAILABLE) {
                flags |= UNAVAILABLE_TEMPERATURE;
            }

            if (broker.sample_count < SAMPLE_CAPACITY) {
                struct sample_record *record = &broker.samples[broker.sample_count];

                record->monotonic_ns = begin;
                record->sclk_mhz = last_sclk;
                record->mclk_mhz = last_mclk;
                record->fclk_mhz = last_fclk;
                record->busy_percent = busy;
                record->temperature_millidegrees = last_temperature;
                record->cost_ns = (uint32_t)(end - begin);
                record->unavailable_flags = flags;
                broker.sample_count++;
                /* The fast path is the sample that reads gpu_busy_percent
                 * alone, which is the cost the sidecar contract bounds. */
                if (tick % DPM_PERIOD_MULTIPLE != 0 &&
                    tick % TEMPERATURE_PERIOD_MULTIPLE != 0 &&
                    tick % MEMORY_PERIOD_MULTIPLE != 0 &&
                    tick % HOST_PERIOD_MULTIPLE != 0) {
                    broker.fast_path_samples++;
                    broker.fast_path_cost_total += record->cost_ns;
                    if (record->cost_ns > broker.fast_path_cost_max) {
                        broker.fast_path_cost_max = record->cost_ns;
                    }
                }
                if (memory_read && broker.memory_count < MEMORY_CAPACITY) {
                    broker.memory[broker.memory_count].monotonic_ns = begin;
                    broker.memory[broker.memory_count].memory_available_kb =
                        memory_available;
                    broker.memory[broker.memory_count].pswpin = pswpin;
                    broker.memory_count++;
                }
                if (host_read && broker.host_count < HOST_CAPACITY) {
                    broker.host[broker.host_count].monotonic_ns = begin;
                    broker.host[broker.host_count].ksm_pages_sharing =
                        ksm_pages_sharing;
                    snprintf(broker.host[broker.host_count].load1,
                             LOAD_TEXT_BYTES, "%s", load_average);
                    broker.host_count++;
                }
            } else if (!broker.ring_full_reported) {
                /* A full ring stops the appending rather than wrapping it, so
                 * first_sample_ns keeps meaning the run start, and the record
                 * carries the mark that says where it stopped. */
                broker.ring_full_reported = true;
                record_mark(&broker, "RING_FULL", begin);
                fprintf(stderr, "telemetry_broker=ring_full samples=%" PRIu64 "\n",
                        broker.sample_count);
                fflush(stderr);
            }

            tick++;

            drain_control(&broker);
            if (broker.paused) {
                wait_while_paused(&broker);
            }
            if (stop_requested != 0) {
                break;
            }
            if (broker.resume_requested) {
                uint64_t now = monotonic_nanoseconds() + period_ns;

                broker.resume_requested = false;
                deadline.tv_sec = (time_t)(now / (uint64_t)NANOSECONDS_PER_SECOND);
                deadline.tv_nsec = (long)(now % (uint64_t)NANOSECONDS_PER_SECOND);
            } else {
                uint64_t next = (uint64_t)deadline.tv_sec *
                                    (uint64_t)NANOSECONDS_PER_SECOND +
                                (uint64_t)deadline.tv_nsec + period_ns;
                uint64_t now = monotonic_nanoseconds();

                /* An overrun beyond one whole period restarts the schedule at
                 * now, which keeps a stall from emitting a burst of expired
                 * deadlines once the machine returns. */
                if (next + period_ns < now) {
                    next = now + period_ns;
                }
                deadline.tv_sec = (time_t)(next / (uint64_t)NANOSECONDS_PER_SECOND);
                deadline.tv_nsec = (long)(next % (uint64_t)NANOSECONDS_PER_SECOND);
            }

            while (clock_nanosleep(CLOCK_MONOTONIC, TIMER_ABSTIME, &deadline, NULL) ==
                   EINTR) {
                if (stop_requested != 0) {
                    break;
                }
            }
        }
    }

    status = write_record(&broker, output_path, period_ns, drm_device,
                          (hwmon != NULL) ? hwmon : "-", affinity_string,
                          applied_nice);
    return status;
}
