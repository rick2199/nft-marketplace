import Header from "../components/header";
import { ContractsProvider } from "../context/ContractsProvider";
import "../styles/globals.css";

function MyApp({ Component, pageProps }) {
  return (
    <ContractsProvider
      addresses={{
        nftAddress: "",
        nftMarketAdress: "",
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
}

export default MyApp;
