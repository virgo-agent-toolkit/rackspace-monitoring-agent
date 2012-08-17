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

#ifndef _virgo_unix_h_
#define _virgo_unix_h_

#ifdef __cplusplus
extern "C" {
#endif /* __cplusplus */

/**
 * Detach a process and daemonize
 */
VIRGO_API(virgo_error_t*) virgo_detach();

#ifdef __cplusplus
}
#endif /* __cplusplus */

#endif /* _virgo_unix_h_ */
