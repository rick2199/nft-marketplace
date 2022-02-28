import { ethers } from "ethers";
import { useEffect, useState } from "react";
import axios from "axios";
import Web3Modal from "web3modal";

import { nftMarketAddress } from "../config";
import NFTMarketplace from "../artifacts/contracts/NFTMarket.sol/NFTMarket.json";

import { INFT } from "../types";
import { useNFTMarketContract } from "../hooks/contracts/useNFTMarketContract";
import { useNFTContract } from "../hooks/contracts/useNFTContract";
import { NFTMarket } from "../__generated__/NFTMarket";

export default function Home() {
  const [nfts, setNfts] = useState<INFT[]>([]);
  const [loading, setLoading] = useState<boolean>(true);
  const ntfMarket = useNFTMarketContract();
  const nft = useNFTContract();
  useEffect(() => {
    loadNFTs();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  async function loadNFTs() {
    const data = await ntfMarket.fetchMarketItems();
    const items: INFT[] = await Promise.all(
      data.map(async (i) => {
        const tokenUri = await nft.tokenURI(i.tokenId);
        const meta = await axios.get(tokenUri);
        let price = ethers.utils.formatUnits(i.price.toString(), "ether");
        let item = {
          price,
          tokenId: i.tokenId.toNumber(),
          seller: i.seller,
          owner: i.owner,
          image: meta.data.image,
          name: meta.data.name,
          description: meta.data.description,
        };
        return item;
      })
    );
    setNfts(items);
    setLoading(false);
  }

  async function buyNFT(nft) {
    const web3modal = new Web3Modal();
    const connection = await web3modal.connect();
    const provider = new ethers.providers.Web3Provider(connection);
    const signer = provider.getSigner();
    const contract = new ethers.Contract(
      nftMarketAddress,
      NFTMarketplace.abi,
      signer
    );
    // ntfMarket.connect(signer)
    const price = ethers.utils.parseUnits(nft.price.toString(), "ether");
    const transaction = await (contract as NFTMarket).createMarketSale(
      nftMarketAddress,
      nft.tokenId,
      { value: price }
    );
    await transaction.wait();
  }

  if (!loading && !nfts.length) return <div>No items on the marketplace</div>;

  return <div>Home</div>;
}
