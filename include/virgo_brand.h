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

/**
 * @file virgo_brand.h
 */

#ifndef _virgo_brand_h_
#define _virgo_brand_h_

#define VIRGO_DEFAULT_NAME \
  "rackspace-monitoring-agent"

#define VIRGO_DEFAULT_EXE_NAME_PREFIX \
  "rackspace-monitoring"

#define VIRGO_DEFAULT_BUNDLE_NAME_PREFIX \
  "monitoring"

#define VIRGO_DEFAULT_BUNDLE_NAME_SUFFIX \
  ".zip"

#define VIRGO_DEFAULT_BUNDLE_NAME \
  VIRGO_DEFAULT_BUNDLE_NAME_PREFIX VIRGO_DEFAULT_BUNDLE_NAME_SUFFIX

#define VIRGO_DEFAULT_CONFIG_WINDOWS_DIRECTORY \
  "Rackspace Agent"

#define VIRGO_DEFAULT_CONFIG_FILENAME \
  VIRGO_DEFAULT_NAME \
  ".cfg"

#define VIRGO_DEFAULT_BUNDLE_UNIX_DIRECTORY \
  "/var/lib/" \
  VIRGO_DEFAULT_NAME \
  "/bundle"

#define VIRGO_DEFAULT_EXE_UNIX_DIRECTORY \
  "/var/lib/" \
  VIRGO_DEFAULT_NAME \
  "/exe"

#define VIRGO_DEFAULT_CONFIG_UNIX_DIRECTORY \
  "/etc"

#define VIRGO_DEFAULT_RUNTIME_UNIX_DIRECTORY \
  "/var/run/" \
  VIRGO_DEFAULT_NAME

#define VIRGO_DEFAULT_PERSISTENT_UNIX_DIRECTORY \
  "/var/lib/" \
  VIRGO_DEFAULT_NAME

#define VIRGO_DEFAULT_LIBRARY_UNIX_DIRECTORY \
  "/usr/lib/" \
  VIRGO_DEFAULT_NAME

#define VIRGO_DEFAULT_ZIP_FILENAME \
  "monitoring.zip"

#define VIRGO_DEFAULT_ZIP_UNIX_PATH \
  "/usr/share/" \
  VIRGO_DEFAULT_NAME \
  "/" VIRGO_DEFAULT_ZIP_FILENAME

#endif
