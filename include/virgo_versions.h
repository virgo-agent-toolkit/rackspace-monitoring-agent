/*
 *  Copyright 2012 Rackspace
 *
 *  Licensed under the Apache License, Version 2.0 (the "License");
 *  you may not use this file except in compliance with the License.
 *  You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 *
 */

#ifndef _virgo_versions_h_
#define _virgo_versions_h_

/* Comparison function for expected filenames */
typedef int(*is_file_cmp)(const char *name);

/* Return -1, 0, or 1 if a filename + version is less than, equal to or greater
 * than
 */
VIRGO_API(int) virgo_compare_versions(const char *a, const char *b);

/* Find the latest filename within a given path.
 * @return VIRGO_SUCCESS on success.
 */
VIRGO_API(virgo_error_t*) virgo__versions_latest_file(virgo_t *v,
                                                      const char *path,
                                                      is_file_cmp file_compare,
                                                      char *buffer,
                                                      size_t buffer_len);

#endif
