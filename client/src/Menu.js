import React, { useState } from "react";
import DateTimePicker from 'react-datetime-picker';
//const { JSDOM } = require( "jsdom" );
//const { window } = new JSDOM( "" );
//const $ = require( "jquery" )( window );

const upperFirst = str => str[0].toUpperCase() + str.slice(1);

const mutezToTez = mutez =>
  Math.round((parseInt(mutez) / 1000000 + Number.EPSILON) * 100) / 100;

const Menu = ({
  tokenInstance,
  ledgerInstance,
  ledgerInfo,
  userAddress,
  setBalance,
  Tezos
}) => {
  const [txStatus, setTxStatus] = useState(null);
  const [txHash, setTxHash] = useState(undefined);

  const debtTokenTransfer = async (userAddress,new_owner,start_date) => {
    try {



    } catch (error) {
      console.log(error);
    }

  }

  const burn = async (userAddress) => {
    try {

      const op = await tokenInstance.methods
        .burn(userAddress)
      console.log(op);
      if (op.status === "applied") {
        setTxStatus("applied");
        setTxHash(op.hash);
      } else {
        setTxStatus("error");
        throw Error("Transation not applied");
      }

      await op.confirmation(30);
      if (op.includedInBlock !== Infinity) {
        setTxStatus("included");
        const newBalance = await Tezos.tz.getBalance(userAddress);
        setBalance(newBalance);
      } else {
        throw Error("Transation not included in block");
      }
    } catch (error) {
      console.log(error);
    }
  };

  if (txStatus === null) {

    return (
      <>
        <div className="app-subtitle">Choose the action you want to perform:</div>
          <div className="card coffee_selection" key={userAddress}>
              <div className="card-footer">
                <div className="card-footer-item">
                  <span
                    className="action"
                    onClick={() => burn(userAddress)}
                  >
                    Burn
                  </span>            
                </div>
                <div className="card-footer-item">
                  <p className="card-padding-line">
                   New creditor: <input type="text" id="newCreditorAccount" value=""></input>
                  </p>
                  <p className="card-padding-line">
                  Date: <DateTimePicker           />
                  </p>
                  <span
                    className="action"
                    onClick={() => debtTokenTransfer(userAddress,document.getElementById("newCreditorAccount").value)}
                  >
                    Transfer
                    </span>                             
                </div>
              </div>
          </div>
      </>
    );
  } else if (txStatus === "applied") {
    return (
      <div className="message is-info">
        <div className="message-header">
          <p>Waiting for confirmation</p>
        </div>
        <div className="message-body">
          <p>Your transaction is being processed, please wait.</p>
          <p className="coffee-loader">
            <img src="coffee-cup.png" alt="coffee-cup" />
          </p>
          <p>Transaction number: {txHash}</p>
        </div>
      </div>
    );
  } else if (txStatus === "included") {
    return (
      <div className="message is-success">
        <div className="message-header">
          <p>Transaction confirmed!</p>
        </div>
        <div className="message-body">
          <p>Xtz has been sent to your account</p>
          <br />
          <p>
            <button
              className="button is-info"
              onClick={() => setTxStatus(null)}
            >
              Xtz redeem
            </button>
          </p>
        </div>
      </div>
    );
  } else if (txStatus === "error") {
    return (
      <div className="message is-danger">
        <div className="message-header">
          <p>Error</p>
        </div>
        <div className="message-body">
          <p>An error has occurred, please try again.</p>
        </div>
      </div>
    );
  }
};

export default Menu;
