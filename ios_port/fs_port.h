/**
 * Copyright (C) 2020, ControlThings Oy Ab
 *
 * Licensed under the Apache License, Version 2.0 (the "License"); you may
 * not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * @license Apache-2.0
 */
/* Unix port specific file I/O functions */
#include "wish_fs.h"

#define APPLE_PATH_MAX_LEN 512

/** Return the path to the iOS app's "Documents" directory. This is the only place we are allowed to store arbitrary data. */
char *get_doc_dir(void);

/** Set the path to the app's Documents dir, so that the Wish filesystem abstraction use it to save files.
    @param str pointer to a null-terminated string representing the documents dir. A copy of this will be made. */
void set_doc_dir(char *str);

wish_file_t my_fs_open(const char *pathname);
int32_t my_fs_read(wish_file_t fd, void* buf, size_t count);
int32_t my_fs_write(wish_file_t fd, const void *buf, size_t count);
wish_offset_t my_fs_lseek(wish_file_t fd, wish_offset_t offset, int whence);
int32_t my_fs_close(wish_file_t fd);
int32_t my_fs_rename(const char *, const char *);
int32_t my_fs_remove(const char *);
