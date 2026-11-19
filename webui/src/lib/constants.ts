// SPDX-License-Identifier: Apache-2.0

export const MODULE_ID = import.meta.env.MODULE_ID as string;

export const MODULE_NAME = "OpenP2P Tunnel";
export const MODULE_VERSION = "1.1.6";
export const MODULE_AUTHOR = "AxoNex";
export const MODULE_LICENSE = "Apache-2.0";
export const REPOSITORY_URL = "https://github.com/AxoNex/openp2p-tunnel";

export const PATHS = {
  CONTROL: `/data/adb/modules/${MODULE_ID}/openp2pctl`,
};
