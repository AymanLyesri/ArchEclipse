export interface Manga {
  provider: string;
  id: string;
  title: string;
  description: string;
  tags: string[];
  year?: number;
  status?: string;
  cover_url: string;
  cover_path: string;
  cover_width?: number;
  cover_height?: number;
}

export interface Chapter {
  id: string;
  title: string;
  chapter?: string;
  volume?: string;
  pages?: number;
  publish_date?: Date;
}

export interface Page {
  url: string;
  path?: string;
  width?: number;
  height?: number;
}
