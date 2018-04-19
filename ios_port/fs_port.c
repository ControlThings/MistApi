#include "wish_fs.h"
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdio.h>
#include <string.h>
#include <errno.h>
#include "fs_port.h"

static char wish_doc_dir[APPLE_PATH_MAX_LEN];

/** Return the path to the iOS app's "Documents" directory. This is the only place we are allowed to store arbitrary data. */
char *get_doc_dir(void) {
    return wish_doc_dir;
}

/** Set the path to the app's Documents dir, so that the Wish filesystem abstraction use it to save files.
 @param str pointer to a null-terminated string representing the documents dir. A copy of this will be made. */
void set_doc_dir(char *str) {
    strncpy(wish_doc_dir, str, APPLE_PATH_MAX_LEN);
}

/* Unix port specific file I/O functions implemented using Posix sys
 * calls */

wish_file_t my_fs_open(const char *pathname) {
    char pathname_docdir[APPLE_PATH_MAX_LEN];
    snprintf(pathname_docdir, APPLE_PATH_MAX_LEN, "%s/%s", get_doc_dir(), pathname);
    
    //printf("opening path %s\n", pathname_docdir);
    wish_file_t retval = open(pathname_docdir, O_RDWR| O_CREAT, S_IRUSR | S_IWUSR);
    if (retval < 0) {
        printf("file error %s\n", strerror(errno));
    }
    return retval;
}

int32_t my_fs_read(wish_file_t fd, void* buf, size_t count) {
    return read(fd, buf, count);
}

int32_t my_fs_write(wish_file_t fd, const void *buf, size_t count) {
    return write(fd, buf, count);
}

wish_offset_t my_fs_lseek(wish_file_t fd, wish_offset_t offset, int whence) {
    return lseek(fd, offset, whence);
}

int32_t my_fs_close(wish_file_t fd) {
    return close(fd);
}

int32_t my_fs_rename(const char *oldpath, const char *newpath) {
    
    char oldpathname_docdir[APPLE_PATH_MAX_LEN];
    char newpathname_docdir[APPLE_PATH_MAX_LEN];
    
    snprintf(oldpathname_docdir, APPLE_PATH_MAX_LEN, "%s/%s", get_doc_dir(), oldpath);
    snprintf(newpathname_docdir, APPLE_PATH_MAX_LEN, "%s/%s", get_doc_dir(), newpath);
    
    return rename(oldpathname_docdir, newpathname_docdir);
}

int32_t my_fs_remove(const char *path) {
    char path_docdir[APPLE_PATH_MAX_LEN];
    snprintf(path_docdir, APPLE_PATH_MAX_LEN, "%s/%s", get_doc_dir(), path);
    
    return remove(path_docdir);
}
