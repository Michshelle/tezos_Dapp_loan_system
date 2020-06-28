type account is record
    balance : nat;
    allowances: map(address, nat);
end
type counter is record
    initialTime : timestamp;
    maturityTime : timestamp;
    creditAmount : nat;
    is_final : bool;
    paybackAmount : nat;
end
type mapforapproval is record
    creditor : address;
    payamount : nat;
end
type register is map (address, counter);
type contract_storage is record
  owner : address;
  totalCredit : nat;
  couponRate_inPerc: nat; //negative interest rate is not considered;
  creditorsMap : register;
  totalSupply: nat;
  ledger: big_map(address, account);
end
type action is
| AddCreditor of (address * nat * int * nat)
| ModifyOwnership of (address * timestamp * nat)
| Mint of (nat)
| Burn of (string * tez * nat)
| Approve of (address * nat)
| CheckPoint

function transfer ( var s : contract_storage; const inaccount : mapforapproval) : contract_storage is
 begin  
    // Fetch src account
    const src: account =
    case s.ledger[Tezos.sender] of
      Some(pattern) -> pattern
    | None -> (failwith ("inaccount is not included") : account)
    end;
    // Check that the owner can spend that much
    if inaccount.payamount > src.balance 
    then failwith ("Source balance is too low");
    else skip;
    // Update the accountFrom balance
    // Using the abs function to convert int to nat
    src.balance := abs(src.balance - inaccount.payamount);
    s.ledger[Tezos.sender] := src;
    // Fetch dst account or add empty dst account to ledger
    var dst: account := record 
        balance = 0n;
        allowances = (map end : map(address, nat));
    end;
    case s.ledger[inaccount.creditor] of
    | None -> skip
    | Some(n) -> dst := n
    end;
    // Update the destination balance
    dst.balance := dst.balance + inaccount.payamount;
    // Decrease the allowance nat if necessary
    case src.allowances[Tezos.sender] of
    | None -> skip
    | Some(dstAllowance) -> src.allowances[Tezos.sender] := abs(dstAllowance - inaccount.payamount)  // ensure non negative
    end;
    s.ledger[Tezos.sender] := src;
    s.ledger[inaccount.creditor] := dst;
 end with s

function mint (const value : nat ; var s : contract_storage) : contract_storage is
 begin
  //const tezAmount : tez = 1000000n * amount;
  //const comp : nat = tezAmount / 1tez;
  //const diff_wrong : bool = (comp < value);
  if Tezos.sender =/= s.owner then failwith("You must be the owner of the contract to mint tokens");
  else block {
    var ownerAccount: account := record 
        balance = 0n;
        allowances = (map end : map(address, nat));
    end;
    case s.ledger[s.owner] of
    | None -> skip
    | Some(n) -> ownerAccount := n
    end;
    // Update the owner balance
    ownerAccount.balance := ownerAccount.balance + value;
    s.ledger[s.owner] := ownerAccount;
    s.totalSupply := s.totalSupply + value;
  }
 end with s

function burn (const settlement : string ; const amounts : tez; const tokens : nat ; var s : contract_storage) : list(operation) * contract_storage is
 begin
  const ops : list(operation) = list [];
  const senderBalance : nat = 0n;
  if Tezos.sender =/= s.owner then 
  block {
    // If the sender is not in the ledger list, it fails
    case s.ledger[Tezos.sender] of 
    | None -> failwith ("Your address must be listed")
    | Some(n) ->  senderBalance := n.balance
    end;
    if settlement = "XTZ" then
    {
      const execontract : contract (unit) =
        case (Tezos.get_contract_opt (Tezos.sender) : option (contract (unit))) of
          Some (contract) -> contract
        | None -> (failwith ("Contract not found.") : contract (unit))
      end;
      const op : operation = Tezos.transaction (unit, amounts, execontract);
      ops := list [op]   
    }
    else skip;
    s.totalSupply := abs(s.totalSupply - senderBalance);
    const poped_ledger : big_map(address, account) = Big_map.remove (Tezos.sender, s.ledger); 
    s.ledger := poped_ledger;
  } else
  block {
    if tokens > s.totalSupply then failwith ("Incorrect token amount, it must be less than total supply.")
    else skip;
    s.totalSupply := abs(s.totalSupply - tokens);
    case s.ledger[Tezos.sender] of 
     | None -> failwith ("Your address must be listed")
     | Some(n) ->  n.balance := abs(n.balance - tokens)
    end;    
  };
 end with (ops,s)

function modifyOwnership (const new_ownership : address ; const change_time : timestamp ; const payback : nat ; var s : contract_storage) : contract_storage is
block {
    if amount =/= 3.0tez then failwith ("Please pay exactly 3 tezos to change the ownership");
    else skip;
    if change_time <= Tezos.now + 86_400 then failwith ("needs to be at least one day later");
    else skip;
    case s.creditorsMap[new_ownership] of
      | Some (c) -> 
        failwith ("new owner has already been on the list")
      | None -> 
        skip
    end;
    case s.creditorsMap[Tezos.sender] of    
    // if creditor is found,change the maturity date
      Some (c) -> {
        if c.is_final = False then failwith ("Not a ultimate creditor");
        else skip;
        if change_time + 86_400 > c.maturityTime then failwith ("needs to be at least one day before maturity time");
        else skip;
        const legacy_initial : timestamp = c.initialTime;
        const legacy_maturity : timestamp = c.maturityTime;
        const legacy_payback : nat = abs(c.paybackAmount - payback);
        const legacy_amount : nat = c.creditAmount;
        const logging : counter =
            record [
              initialTime       = change_time;  //const some_date : timestamp = ("2000-01-01T10:10:10Z" : timestamp)
              maturityTime      = legacy_maturity;
              creditAmount = legacy_amount;
              paybackAmount = legacy_payback;
              is_final = True;
            ];
        s.creditorsMap := Map.add(new_ownership,logging,s.creditorsMap);
        s.creditorsMap := Map.remove(Tezos.sender,s.creditorsMap);
        const old_log : counter =
            record [
              initialTime       = legacy_initial;
              maturityTime      = change_time;
              creditAmount = legacy_amount;
              paybackAmount = payback;
              is_final = False;              
            ];
        s.creditorsMap := Map.add(Tezos.sender,old_log,s.creditorsMap);
       }
     | None -> 
      failwith ("Creditor contract does not exist")
    end;
} with s

function approve (const spender : address ; const value : nat ; var s : contract_storage) : contract_storage is
 begin
  // If sender is the spender approving is not necessary
  if sender = spender then skip;
  else block {
    const src: account = 
    case s.ledger[sender] of 
      Some(pattern) -> pattern
    | None -> (failwith("Account is not included") : account)
    end;
    src.allowances[spender] := value;
    s.ledger[sender] := src; // Not sure if this last step is necessary
  }
 end with s


function addCreditor (const creditor : address ; const lendingValue : nat ; const duration : int ; const payback : nat ; var s : contract_storage) : contract_storage is
 begin
  if amount =/= 0tz then failwith ("This entrypoint does not accept token");
  else skip;
  if s.owner =/= Tezos.sender then failwith ("Only owner can modify the capital");
  else skip;
  // If owner and the creditor is same, skip
  if s.owner = creditor then failwith ("Creditor contract does not exist");
  else block {
      case s.creditorsMap[creditor] of
        // if creditor is found, he cannot participate in again.
         Some (c) -> 
          failwith ("Creditor contract does not reach maturity") // if no record found, add it
        | None -> {
          const right_now : timestamp = Tezos.now;
          const one_day : int = 86_400;
          const logging : counter =
              record [
                initialTime       = right_now;
                //const some_date : timestamp = ("2000-01-01T10:10:10Z" : timestamp)
                maturityTime      = right_now + one_day * duration;
                is_final = True;
                creditAmount = lendingValue;
                paybackAmount = payback;
              ];
          s.creditorsMap := Map.add(creditor,logging,s.creditorsMap);
          s.totalCredit := s.totalCredit + lendingValue;
          if s.totalCredit > s.totalSupply then failwith ("Debt is greater than collateral");
          else skip;
        }
      end;
   
  }
 end with s

function removeCreditor (var s : contract_storage ; const inaccount : mapforapproval) : contract_storage is
 begin
  // If owner and the creditor is same, skip
  if s.owner = inaccount.creditor then failwith ("Creditor contract does not exist");
  else block {
      case s.creditorsMap[inaccount.creditor] of
        // if creditor is found, remove the record
          Some (c) -> {
          //const diff_day = (c.maturityTime - c.initialTime) / 86400;  //to get duration
          if c.is_final = True then 
          block {
            s.totalCredit := abs(s.totalCredit - c.creditAmount);
          }
          else skip;
          s.creditorsMap := Map.remove(inaccount.creditor,s.creditorsMap);
          }
        | None -> 
          failwith ("Creditor contract does not exist")
      end;
  }
 end with s

function fold_op (var m : register) : list(mapforapproval) is 
block {
  const iii : list(mapforapproval) = list [];
  for key -> value in map m block {
      if value.maturityTime <= Tezos.now then 
      {
        const logger : mapforapproval =
            record [
              creditor       = key;
              payamount = value.paybackAmount;
            ];
        iii := logger # iii;
        }
      else skip;
  }
} with iii

function checkPoint (var s : contract_storage) : contract_storage is 
 begin
   if amount =/= 0tz then failwith ("This entrypoint does not accept token");
   else skip;
   if s.owner =/= Tezos.sender then failwith ("Only owner can call");
   else skip;
   const remove_creditors : list(mapforapproval) = fold_op (s.creditorsMap); 
   const ops : list(operation) = nil;
   if List.length(remove_creditors) = 0n then skip;
   else block {
     s := List.fold (transfer, remove_creditors, s);
     s := List.fold (removeCreditor, remove_creditors, s);
   };
 end with (s)
 
function main (const p : action ; const s : contract_storage) : (list(operation) * contract_storage) is
  block {
      const receiver : contract (unit) = 
      case (Tezos.get_contract_opt (s.owner): option(contract(unit))) of 
        Some (contract) -> contract
      | None -> (failwith ("Not a contract") : (contract(unit)))
      end;
    const payoutOperation : operation = Tezos.transaction (unit, amount, receiver);
    const operations : list(operation) = list [payoutOperation]    
  } with case p of 
  | AddCreditor(n) -> ((nil : list(operation)), addCreditor(n.0,n.1,n.2,n.3,s))
  | Approve(n) -> ((nil : list(operation)), approve(n.0, n.1, s))
  | ModifyOwnership(n) ->  ((operations : list(operation)), modifyOwnership(n.0,n.1,n.2,s))
  | CheckPoint -> ((nil : list(operation)), checkPoint(s))
  | Mint(n) -> ((nil : list(operation)), mint(n, s))
  | Burn(n) -> burn(n.0,n.1,n.2,s)
 end