import { Api } from "../interfaces/api.interface";

export const chatBotApis: Api[] = [
  {
    name: "Phind",
    value: "phind",
    icon: "Ph",
    description: "Uses Phind Model. Great for developers",
  },
  {
    name: "Pollinations",
    value: "pollinations",
    icon: "Po",
    description: "Completely free, default model is gpt-4o",
    imageGenerationSupport: true,
  },
  {
    name: "Isou",
    value: "isou",
    icon: "Is",
    description: "Free provider with web search capabilities",
  },
  {
    name: "KoboldAI",
    value: "koboldai",
    icon: "Ko",
    description: "Creative writing focused, answers from novels",
  },
  {
    name: "Arta",
    value: "arta",
    icon: "Ar",
    description: "AI image generation with various artistic styles",
    imageGenerationSupport: true,
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
