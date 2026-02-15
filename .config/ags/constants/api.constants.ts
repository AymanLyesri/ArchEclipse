import { Api } from "../interfaces/api.interface";

export const chatBotApis: Api[] = [
  {
    name: "Gpt 4o mini",
    value: "openai/gpt-4o-mini",
    icon: "G4o",
    description: "OpenAI's gpt-4o-mini model, versatile and efficient",
  },
  {
    name: "Deepseek R1",
    value: "deepseek/deepseek-r1",
    icon: "DsR1",
    description: "Deepseek's R1 model, optimized for contextual understanding",
  },
  {
    name: "Meta Llama 3.2 1B Instruct",
    value: "meta-llama/llama-3.2-1b-instruct",
    icon: "L3.2",
    description:
      "Meta's Llama 3.2 1B Instruct model, designed for instruction following",
  },
  {
    name: "Mistral 8B",
    value: "mistralai/ministral-8b-2512",
    icon: "M8B",
    description:
      "Mistral AI's Ministral 8B model, optimized for efficiency and performance",
  },
];

export const booruApis: Api[] = [
  {
    name: "Danbooru",
    value: "danbooru",
    idSearchUrl: "https://danbooru.donmai.us/posts/",
  },
  {
    name: "Gelbooru",
    value: "gelbooru",
    idSearchUrl: "https://gelbooru.com/index.php?page=post&s=view&id=",
  },
  {
    name: "Safebooru",
    value: "safebooru",
    idSearchUrl: "https://safebooru.donmai.us/posts/",
  },
];
