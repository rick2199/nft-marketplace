import Header from "../components/header";
import { ContractsProvider } from "../context/ContractsProvider";
import { AppProps } from "next/app";
import "../styles/globals.css";
import { nftAddress, nftMarketAddress } from "../config";

const MyApp: React.FC<AppProps> = ({ Component, pageProps }) => {
  return (
    <ContractsProvider
      addresses={{
        nftAddress,
        nftMarketAddress,
      }}
      autoInit
      loadingComponent={<div>Loading...</div>}
    >
      <Header />
      <main>
        <Component {...pageProps} />
      </main>
    </ContractsProvider>
  );
};

export default MyApp;
