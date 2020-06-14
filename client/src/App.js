import React, { useState, useEffect } from "react";
import { Tezos } from "@taquito/taquito";
import { TezBridgeSigner } from "@taquito/tezbridge-signer";
import Menu from "./Menu";
import "./App.css";
import "./bulma.css";




/* PUT HERE THE CONTRACT ADDRESS FOR YOUR OWN SANDBOX! */
const KT_ledger = "KT1RigSYegqvkCkEoHMfgXY4XLgknZufrFEa"
const KT_token = "KT1GxBkvP5aiAtBu9MwAWBgxRpaCeLCcBfNj"


const shortenAddress = addr =>
  addr.slice(0, 6) + "..." + addr.slice(addr.length - 6);

const App = () => {
  const [tokenInstance, setTokenInstance] = useState(undefined);
  const [xtzPrice, setXtzPrice] = useState(undefined);
  const [ledgerInstance, setLedgerInstance] = useState(undefined);
  const [ledgerInfo, setLedgerInfo] = useState(undefined);
  const [userAddress, setUserAddress] = useState(undefined);
  const [balance, setBalance] = useState(undefined);
  const [isOwner, setIsOwner] = useState(false);
  const [contractBalance, setContractBalance] = useState(0);
  const tezbridge = window.tezbridge;

  const tezosPrice = async() => {
    try {
      const fetch = require('node-fetch') 
      const req = await fetch("https://api-pub.bitfinex.com/v2/ticker/tXTZUSD", { headers : { 'Access-Control-Allow-Origin': '*' }})
      const response = await req.json()               
      const _xtz = Number(response[0])
      setXtzPrice(_xtz);
    } catch (error) {
      console.log("error fetching the address or balance:", error);
    }
  };


  const initWallet = async () => {
    try {
      /*............remove...........*/
      /*.............remove..........*/
      //const response = await r2("https://api-pub.bitfinex.com/v2/ticker/tXTZUSD").json;
      //const _xtz = Number(response[0])
      //setXtzPrice(_xtz);
      const _address = await tezbridge.request({ method: "get_source" });
      setUserAddress(_address);
      // gets user's balance
      const _balance = await Tezos.tz.getBalance(_address);
      setBalance(_balance);
      const storage = await tokenInstance.storage();
      if (storage.owner === _address) {
        setIsOwner(true);
        const _contractBalance = await Tezos.tz.getBalance(KT_token);
        setContractBalance(_contractBalance.c[0]);
      }
    } catch (error) {
      console.log("error fetching the address or balance:", error);
    }
  };

  const mint = async (mintNumber,xtz) => {
    // sends mint request
    const price = mintNumber / 1000000 / xtz;
    const op = await tokenInstance.methods.mint(mintNumber).send({ amount: price.toFixed(4) });
    // waits for confirmation
    await op.confirmation(30);
    // if confirmed
    if (op.includedInBlock !== Infinity) {
      const newBalance = await Tezos.tz.getBalance(userAddress);
      setBalance(newBalance);
    } else {
      console.log("error");
    }
  };

  useEffect(() => {
    (async () => {
      // sets RPC
      Tezos.setProvider({
        rpc: "https://tezos-dev.cryptonomic-infra.tech",
        signer: new TezBridgeSigner()
      });
      const tokenContract = await Tezos.contract.at(KT_token);
      setTokenInstance(tokenContract);
      const ledgerContract = await Tezos.contract.at(KT_ledger);
      setLedgerInstance(ledgerContract);
      const ledgerStorage = await ledgerContract.storage();
      // creates token contract info
      let ledgerInfos = [ledgerStorage.debtor,ledgerStorage.totalCredit];
      setLedgerInfo(ledgerInfos);
    })();
  }, []);
  return (
    <div className="App">
      <div className="wallet">
        {balance === undefined ? (
          <button
            className="button is-info is-light is-small"
            onClick={initWallet}
          >
            Connect your wallet
          </button>
        ) : (
          <>
            <span className="balance">ꜩ {balance.toNumber() / 1000000}</span>
            <div className="field is-grouped">
              <p className="control">
                <button
                  className="button is-success is-light is-small"
                  onClick={async () => {
                    setUserAddress(undefined);
                    setBalance(undefined);
                    setIsOwner(undefined);
                    setXtzPrice(undefined);
                    await initWallet();
                  }}
                >
                  {shortenAddress(userAddress)}
                </button>
              </p>
              {isOwner && (
                <p className="control">
                  <button
                    className="button is-warning is-light is-small"
                    onClick={async () => {
                     await tezosPrice();
                     mint(document.getElementById("tokenNumber").value,xtzPrice);
                     document.getElementById("tokenNumber").value = "";
                    }
                    }
                  >
                    Mint token
                  </button>
                  <input type="text" id="tokenNumber"></input>
                </p>
              )}
            </div>
          </>
        )}
      </div>
      <div className="app-title">Flexible Loans</div>
      <div className="logo">
        <img src="coffee-maker.png" alt="logo" />
      </div>
      {typeof ledgerInfo === 'undefined' ? (
        "Loading the ledger info..."
      ) : (
        <Menu
          ledgerInfo={ledgerInfo}
          tokenInstance={tokenInstance}
          ledgerInstance={ledgerInstance}
          userAddress={userAddress}
          setBalance={setBalance}
          Tezos={Tezos}
        />
      )}
    </div>
  );
};

export default App;
