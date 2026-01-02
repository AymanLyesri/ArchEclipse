import { Api, ApiClass } from "./api.interface";

export interface Waifu {
  id: number;
  width: number;
  height: number;
  api: Api;
  tags: string[];
  extension?: string;
  url?: string;
  preview?: string;
}

export class WaifuClass implements Waifu {
  // Implement the Waifu interface
  id: number;
  width: number;
  height: number;
  api: Api;
  tags: string[] = [];
  extension?: string;
  url?: string;
  preview?: string;

  constructor(waifu: Waifu = {} as Waifu) {
    this.id = waifu.id;
    this.url = waifu.url;
    // this.url_file_path = waifu.url_file_path;
    this.preview = waifu.preview;
    // this.preview_file_path = waifu.preview_file_path;
    this.width = waifu.width;
    this.height = waifu.height;
    this.api = waifu.api || new ApiClass();
    this.extension = waifu.extension;
    this.tags = waifu.tags || [];
  }
}

// export interface bookMarkWaifus= Waifu[];
