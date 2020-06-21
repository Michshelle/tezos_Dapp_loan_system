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
  debtor : address;
  totalCredit : int;
  capitalAmount : int;
  couponRate_inPerc: nat; //negative interest rate is not considered;
  creditorsMap : register;
end
type action is
| ModifyCapital of (int)
| AddCreditor of (address * nat * int * nat)
| ModifyOwnership of (address * timestamp * nat)
| GetCouponRate of (unit * contract(nat))
| GetTotalCredit of (unit * contract(int))
| CheckPoint

const removing_list : list(address) = list [];
const ownerAddress : address =
  ("tz1NBWgCxEGy8U6UA4hRmemt3YmMXbPPe1YH" : address);
const exectAddress : address =
  ("KT1K9UbyNBtjBaoz5vERevagiCXG6qgtaRRy" : address);
type parameter is
| Transfer of (address * address * nat)

function getCouponRate (const contr : contract(nat) ; var s : contract_storage) : list(operation) is
  list [Tezos.transaction(s.couponRate_inPerc, 0tz, contr)]

function getTotalCredit (const contr : contract(int) ; var s : contract_storage) : list(operation) is
  list [Tezos.transaction(s.totalCredit, 0tz, contr)]

function proxy_transfer (const store : mapforapproval): list(operation) is
  block {
    const execontract : contract (parameter) =
      case (Tezos.get_contract_opt (exectAddress) : option (contract (parameter))) of
        Some (contract) -> contract
      | None -> (failwith ("Contract not found.") : contract (parameter))
      end;
    const mock_param : parameter = Transfer (ownerAddress ,store.creditor, store.payamount);
    const op : operation = Tezos.transaction (mock_param, 0tez, execontract);
    const ops : list (operation) = list [op]
  } with (ops)


function fold_proxyissue (var m : map (address , counter)) : list(operation) is 
block {
  const iii : list(operation) = nil;
  for key -> value in map m block {
      if value.maturityTime <= Tezos.now then 
      {
        const logger : mapforapproval =
            record [
              creditor       = key;
              payamount = value.paybackAmount;
            ];
        iii := proxy_transfer (logger);  
        }
      else skip;
  }
} with iii

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

function modifyCapital (const capitalInplace : int ; var s : contract_storage) : contract_storage is
 begin 
  if amount =/= 0tz then failwith ("This entrypoint does not accept token");
  else skip;
  if s.debtor =/= Tezos.sender then failwith ("Only debtor can modify the capital");
  else block {
     s.capitalAmount := capitalInplace
  }
 end with s

function addCreditor (const creditor : address ; const lendingValue : nat ; const duration : int ; const payback : nat ; var s : contract_storage) : contract_storage is
 begin

  if amount =/= 0tz then failwith ("This entrypoint does not accept token");
  else skip;
  if s.debtor =/= Tezos.sender then failwith ("Only debtor can modify the capital");
  else skip;
  // If debtor and the creditor is same, skip
  if s.debtor = creditor then failwith ("Creditor contract does not exist");
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
        }
      end;
  }
 end with s

function removeCreditor (var s : contract_storage ; const creditor : address) : contract_storage is
 begin
  // If debtor and the creditor is same, skip
  if s.debtor = creditor then failwith ("Creditor contract does not exist");
  else block {
      case s.creditorsMap[creditor] of
        // if creditor is found, remove the record
          Some (c) -> {
          //const diff_day = (c.maturityTime - c.initialTime) / 86400;  //to get duration
          if c.is_final = True then 
          block {
            const new_debt : int = s.totalCredit - c.creditAmount;
            if new_debt < 0 then failwith ("totalCredits cannot be less than zero.");
            else skip;
            s.totalCredit := new_debt
          }
          else skip;
          s.creditorsMap := Map.remove(creditor,s.creditorsMap);
          }
        | None -> 
          failwith ("Creditor contract does not exist")
      end;
  }
 end with s

function fold_op (const m : register) : list(address) is
  block {
    function folded (const i : list(address); const j : address * counter) : list(address) is
      if j.1.maturityTime <= Tezos.now then j.0 # i else i;
  } with Map.fold (folded, m, removing_list)


function checkPoint (var s : contract_storage) : (list(operation)) * contract_storage is 
 begin
   if amount =/= 0tz then failwith ("This entrypoint does not accept token");
   else skip;
   if s.debtor =/= Tezos.sender then failwith ("Only debtor can call");
   else skip;
   const remove_creditors : list(address) = fold_op (s.creditorsMap); 
   const ops : list(operation) = nil;
   if List.length(remove_creditors) = 0n then skip;
   else block {
     ops := fold_proxyissue(s.creditorsMap);
     s := List.fold (removeCreditor, remove_creditors, s);
   };
 end with (ops,s)
 
function main (const p : action ; const s : contract_storage) :
  (list(operation) * contract_storage) is
  block {
      const receiver : contract (unit) = 
      case (Tezos.get_contract_opt (ownerAddress): option(contract(unit))) of 
        Some (contract) -> contract
      | None -> (failwith ("Not a contract") : (contract(unit)))
      end;
    const payoutOperation : operation = Tezos.transaction (unit, amount, receiver);
    const operations : list(operation) = list [payoutOperation]  
    
  } with case p of 
  | ModifyCapital(k) -> ((nil : list(operation)), modifyCapital(k,s))
  | AddCreditor(n) -> ((nil : list(operation)), addCreditor(n.0,n.1,n.2,n.3,s))
  | ModifyOwnership(n) ->  ((operations : list(operation)), modifyOwnership(n.0,n.1,n.2,s))
  | GetCouponRate(n) -> (getCouponRate(n.1, s), s)
  | GetTotalCredit(n) -> (getTotalCredit(n.1, s), s)
  | CheckPoint -> checkPoint(s)
 end