/*
 * Read Steam Controller 2 battery reports from Linux hidraw devices.
 *
 * The device scan and report loop are based on scbat by Grégoire Delattre:
 * https://github.com/gregdel/scbat
 * Copyright (c) 2026 Grégoire Delattre. Licensed under the MIT License.
 */

#define _GNU_SOURCE

#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <linux/hidraw.h>
#include <poll.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <sys/ioctl.h>
#include <time.h>
#include <unistd.h>

#define STEAM_VENDOR_ID 0x28de
#define STEAM_CONTROLLER_ID 0x1302
#define STEAM_PUCK_ID 0x1304
#define BATTERY_REPORT_ID 0x43
#define BATTERY_REPORT_LENGTH 15
#define MAX_DEVICES 16
#define MAX_READS_PER_WAKE 64
#define TIMEOUT_MS 4000

static int hidraw_number(const char *name)
{
    const char *cursor;
    int number = 0;

    if (strncmp(name, "hidraw", 6) != 0 || name[6] == '\0')
        return -1;

    for (cursor = name + 6; *cursor; cursor++) {
        if (*cursor < '0' || *cursor > '9')
            return -1;
        number = number * 10 + *cursor - '0';
    }

    return number;
}

static int64_t monotonic_ms(void)
{
    struct timespec now;

    if (clock_gettime(CLOCK_MONOTONIC, &now) < 0)
        return -1;
    return (int64_t)now.tv_sec * 1000 + now.tv_nsec / 1000000;
}

static int emit_battery(const uint8_t *report, ssize_t length)
{
    const char *state;
    const char *charging;
    unsigned int percentage;

    if (length < BATTERY_REPORT_LENGTH || report[0] != BATTERY_REPORT_ID)
        return 0;

    percentage = report[2];
    if (percentage > 100)
        return 0;

    switch (report[1]) {
    case 1:
        state = "discharging";
        charging = "false";
        break;
    case 2:
    case 3:
        state = "charging";
        charging = "true";
        break;
    case 4:
        state = "fully-charged";
        charging = "true";
        break;
    default:
        state = "unknown";
        charging = "false";
        break;
    }

    if (printf("{\"connected\":true,\"pct\":%u,\"state\":\"%s\","
               "\"charging\":%s,\"id\":\"steam-controller-2\","
               "\"type\":\"gamepad\",\"model\":\"Steam Controller\"}\n",
               percentage, state, charging) < 0)
        return -1;

    return 1;
}

int main(void)
{
    struct pollfd devices[MAX_DEVICES];
    struct dirent *entry;
    DIR *directory;
    int directory_fd;
    int active;
    int count = 0;
    int64_t deadline;

    directory = opendir("/dev");
    if (!directory)
        return 1;
    directory_fd = dirfd(directory);
    if (directory_fd < 0) {
        closedir(directory);
        return 1;
    }

    while (count < MAX_DEVICES && (entry = readdir(directory))) {
        struct hidraw_devinfo info = {0};
        int fd;

        if (hidraw_number(entry->d_name) < 0)
            continue;

        fd = openat(directory_fd, entry->d_name,
                    O_RDONLY | O_NONBLOCK | O_CLOEXEC);
        if (fd < 0)
            continue;

        if (ioctl(fd, HIDIOCGRAWINFO, &info) < 0
            || info.vendor != STEAM_VENDOR_ID
            || (info.product != STEAM_CONTROLLER_ID
                && info.product != STEAM_PUCK_ID)) {
            close(fd);
            continue;
        }

        devices[count++] = (struct pollfd){.fd = fd, .events = POLLIN};
    }

    if (closedir(directory) < 0 || count == 0)
        return 1;

    active = count;
    deadline = monotonic_ms();
    if (deadline < 0)
        return 1;
    deadline += TIMEOUT_MS;

    while (active > 0) {
        int64_t now = monotonic_ms();
        int ready;
        int i;

        if (now < 0 || now >= deadline)
            return 1;

        ready = poll(devices, count, (int)(deadline - now));
        if (ready < 0 && errno == EINTR)
            continue;
        if (ready <= 0)
            return 1;

        for (i = 0; i < count; i++) {
            int failed = 0;
            int read_count;

            if (devices[i].fd < 0 || devices[i].revents == 0)
                continue;

            if (devices[i].revents & POLLIN) {
                for (read_count = 0; read_count < MAX_READS_PER_WAKE;
                     read_count++) {
                    uint8_t report[64];
                    ssize_t length = read(devices[i].fd, report, sizeof(report));
                    int emitted;

                    if (length > 0) {
                        emitted = emit_battery(report, length);
                        if (emitted > 0)
                            return 0;
                        if (emitted < 0)
                            return 2;
                        continue;
                    }
                    if (length < 0 && errno == EINTR)
                        continue;
                    if (length < 0
                        && (errno == EAGAIN || errno == EWOULDBLOCK))
                        break;
                    failed = 1;
                    break;
                }
            }

            if (devices[i].revents & (POLLERR | POLLHUP | POLLNVAL))
                failed = 1;
            if (failed) {
                close(devices[i].fd);
                devices[i].fd = -1;
                active--;
            }
        }
    }

    return 1;
}
