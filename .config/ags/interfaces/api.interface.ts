export interface Api {
  name: string;
  value: string;
  icon?: string;
  description?: string;
  idSearchUrl?: string;
  imageGenerationSupport?: boolean;
}

export class ApiClass implements Api {
  name: string;
  value: string;
  icon?: string;
  description?: string;
  idSearchUrl?: string;
  imageGenerationSupport?: boolean;

  constructor(api: Api = {} as Api) {
    this.name = api.name;
    this.value = api.value;
    this.icon = api.icon;
    this.description = api.description;
    this.idSearchUrl = api.idSearchUrl;
    this.imageGenerationSupport = api.imageGenerationSupport;
  }
}
