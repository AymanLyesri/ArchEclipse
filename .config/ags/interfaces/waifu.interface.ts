import { Api } from "./api.interface";

export interface Waifu {
  id: number;
  url?: string;
  // url_file_path?: string;
  preview?: string;
  // preview_file_path?: string;
  width: number;
  height: number;
  api: Api;
}

export class WaifuClass implements Waifu {
  // Implement the Waifu interface
  id: number;
  url?: string;
  // url_file_path?: string;
  preview?: string;
  // preview_file_path?: string;
  width: number;
  height: number;
  api: Api;

  constructor(waifu: Waifu = {} as Waifu) {
    this.id = waifu.id;
    this.url = waifu.url;
    // this.url_file_path = waifu.url_file_path;
    this.preview = waifu.preview;
    // this.preview_file_path = waifu.preview_file_path;
    this.width = waifu.width;
    this.height = waifu.height;
    this.api = waifu.api;
  }
}
