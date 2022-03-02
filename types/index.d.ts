export interface INFT {
  price: string;
  tokenId: number;
  seller: string;
  owner: string;
  image: string;
  name?: string;
  description?: string;
}

export interface IItem {
  price: string;
  tokenId: number;
  seller: string;
  owner: string;
  sold: boolean;
  image: string;
}
