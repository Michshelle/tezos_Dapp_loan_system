import React, { useState } from "react";
import MyApp from "./datetimepicker";


const shortenAddress = addr =>
  addr.slice(0, 6) + "..." + addr.slice(addr.length - 6);

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

  const [burnBalance, setBurnBalance] = useState(undefined);
  const debtTokenTransfer = async (new_owner,start_date,paybackAmount) => {
    try {
      const op = await ledgerInstance.methods
        .modifyOwnership(new_owner, start_date, paybackAmount)
        .send({ amount: 3000000, mutez: true });
      await op.confirmation(30);
      if (op.includedInBlock !== Infinity) {
        const newBalance = await Tezos.tz.getBalance(userAddress);
        setBalance(newBalance);
      } else {
        throw Error("Transation not included in block");
      }
    } catch (error) {
      console.log(error);
    }
  }

  const burn = async () => {
    try {
      const tokenStorage = await tokenInstance.storage()
      if (userAddress === tokenStorage.owner) { 
        throw Error("The burn on webpage is only designed for creditors! Use commandline to burn as the token owner! ");
      }
      const userToken = await tokenStorage.ledger.get(userAddress)
      const balanceToken = userToken.balance
      if (typeof balanceToken === "undefined") { 
        throw Error("Cannot find the account possesses any debt token. ");
      }
      const req = await fetch("https://api-pub.bitfinex.com/v2/ticker/tXTZUSD", { headers : { 'Access-Control-Allow-Origin': '*' }})
      const response = await req.json()    
      const xtzPrice = Number(response[0])
      const amounts = Math.round(balanceToken / xtzPrice)  //in mutez
      const settlement = "XTZ"  //this can be an option in future at the frontend.  The settlement can be in USD and etc.
      const op = await tokenInstance.methods.burn(settlement, amounts, 0).send({ amount: 0 });
      await op.confirmation(30);
      if (op.includedInBlock !== Infinity) {
        const newBalance = await Tezos.tz.getBalance(userAddress);
        setBalance(newBalance);
        setBurnBalance(newBalance);
      } else {
        console.log("Transaction is not included in the block");
      }
    } catch (error) {
      console.log(error);
    }
  };
  return (
    <>
        setValue(value) {
            this.setState(value)
        }
        <div className="app-subtitle">Choose the action you want to perform:</div>
          <p>USD{ ledgerInfo[1] /10000} has been raised for the debt account { shortenAddress(ledgerInfo[0]) }.</p>
            <div className="card coffee_selection" key={userAddress}>
              <div className="card-footer">
                <div className="card-footer-item">
                { burnBalance === undefined ? (
                  <span
                    className="action"
                    onClick={async () => {
                      setBurnBalance(undefined);
                      await burn();
                    }
                 }
                  >
                    Burn
                  </span>
                ) : (
                   <span 
                      className="actioned"  
                   >
                     Burnt
                   </span> 
                )}          
                </div>
                <div className="card-footer-item">
                  <div className="card-padding-line"> 
                   New creditor: 
                  </div>
                  <div className="card-padding-line">
                   <input type="text" id="newCreditorAccount" ></input>
                   </div>

                  <div>
                  <MyApp setValue={this.setValue} value={this.state.value} />
                  </div>
                  <span
                    className="action"
                    onClick={ () => {
                      alert(MyApp.value);
                      const paybackAmount = 0;
                      debtTokenTransfer(userAddress,document.getElementById("newCreditorAccount").value, paybackAmount)
                      }
                    }
                  >
                    Transfer Ownership
                  </span>                             
                </div>
              </div>
            </div>
    </>
  );
};
    
export default Menu;
