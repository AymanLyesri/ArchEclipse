export interface Message {
  id: string;
  role: string;
  content: string;
  timestamp: number;
  responseTime?: number;
  image?: string;
}

export interface Provider {
  name: string;
  icon: string;
  description: string;
  imageGenerationSupport?: boolean;
}
