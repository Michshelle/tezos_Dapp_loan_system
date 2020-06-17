type account is record
    balance : nat;
    allowances: map(address, nat);
end

type action is
| Transfer of (address * address * nat)
| Mint of (nat)
| Burn of (string * tez * nat)
| Approve of (address * nat)
| GetAllowance of (address * address * contract(nat))
| GetBalance of (address * contract(nat))
| GetTotalSupply of (unit * contract(nat))

type contract_storage is record
  owner: address;
  totalSupply: nat;
  ledger: big_map(address, account);
end

function isAllowed (const accountFrom : address ; const value : nat ; var s : contract_storage) : bool is 
  begin
    var allowed: bool := False;
    if sender =/= accountFrom then block {
      // Checking if the sender is allowed to spend in name of accountFrom
      const src: account = get_force(accountFrom, s.ledger);
      const allowanceAmount: nat = get_force(sender, src.allowances);
      allowed := allowanceAmount >= value;
    };
    else allowed := True;
  end with allowed

// Transfer a specific nat of tokens from accountFrom address to a destination address
// Preconditions:
//  The sender address is the account owner or is allowed to spend x in the name of accountFrom
//  The accountFrom account has a balance higher than the nat
// Postconditions:
//  The balance of accountFrom is decreased by the nat
//  The balance of destination is increased by the nat
function transfer (const accountFrom : address ; const destination : address ; const value : nat ; var s : contract_storage) : contract_storage is
 begin  
  // If accountFrom = destination transfer is not necessary
  if accountFrom =/= Tezos.sender then failwith ("At the moment, only transfer token amount in your own account")
  else block {
  if accountFrom = destination then skip;
  else block {
    // Is sender allowed to spend value in the name of accountFrom
    case isAllowed(accountFrom, value, s) of 
    | False -> failwith ("Sender not allowed to spend token from source")
    | True -> skip
    end;

    // Fetch src account
    const src: account = get_force(accountFrom, s.ledger);

    // Check that the accountFrom can spend that much
    if value > src.balance 
    then failwith ("Source balance is too low");
    else skip;

    // Update the accountFrom balance
    // Using the abs function to convert int to nat
    src.balance := abs(src.balance - value);

    s.ledger[accountFrom] := src;

    // Fetch dst account or add empty dst account to ledger
    var dst: account := record 
        balance = 0n;
        allowances = (map end : map(address, nat));
    end;
    case s.ledger[destination] of
    | None -> skip
    | Some(n) -> dst := n
    end;

    // Update the destination balance
    dst.balance := dst.balance + value;

    // Decrease the allowance nat if necessary
    case src.allowances[sender] of
    | None -> skip
    | Some(dstAllowance) -> src.allowances[sender] := abs(dstAllowance - value)  // ensure non negative
    end;

    s.ledger[accountFrom] := src;
    s.ledger[destination] := dst;
  }
  }
 end with s

function mint (const value : nat ; var s : contract_storage) : contract_storage is
 begin
  // If the sender is not the owner fail
  if sender =/= s.owner then failwith("You must be the owner of the contract to mint tokens");
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

function burn (const settlement : string ; const amounts : tez ; const tokens : nat ; var s : contract_storage) : list(operation) * contract_storage is
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
 end with (ops,s)

// Approve an nat to be spent by another address in the name of the sender
// Preconditions:
//  The spender account is not the sender account
// Postconditions:
//  The allowance of spender in the name of sender is value
function approve (const spender : address ; const value : nat ; var s : contract_storage) : contract_storage is
 begin
  // If sender is the spender approving is not necessary
  if sender = spender then skip;
  else block {
    const src: account = get_force(sender, s.ledger);
    src.allowances[spender] := value;
    s.ledger[sender] := src; // Not sure if this last step is necessary
  }
 end with s

// View function that forwards the allowance nat of spender in the name of owner to a contract
// Preconditions:
//  None
// Postconditions:
//  The state is unchanged
function getAllowance (const owner : address ; const spender : address ; const contr : contract(nat) ; var s : contract_storage) : list(operation) is
 begin
  const src: account = get_force(owner, s.ledger);
  const destAllowance: nat = get_force(spender, src.allowances);
 end with list [transaction(destAllowance, 0tz, contr)]

// View function that forwards the balance of source to a contract
// Preconditions:
//  None
// Postconditions:
//  The state is unchanged
function getBalance (const accountFrom : address ; const contr : contract(nat) ; var s : contract_storage) : list(operation) is
 begin
  const src: account = get_force(accountFrom, s.ledger);
 end with list [transaction(src.balance, 0tz, contr)]

// View function that forwards the totalSupply to a contract
// Preconditions:
//  None
// Postconditions:
//  The state is unchanged
function getTotalSupply (const contr : contract(nat) ; var s : contract_storage) : list(operation) is
  list [transaction(s.totalSupply, 0tz, contr)]

function main (const p : action ; const s : contract_storage) :
  (list(operation) * contract_storage) is
 case p of
  | Transfer(n) -> ((nil : list(operation)), transfer(n.0, n.1, n.2, s))
  | Approve(n) -> ((nil : list(operation)), approve(n.0, n.1, s))
  | GetAllowance(n) -> (getAllowance(n.0, n.1, n.2, s), s)
  | GetBalance(n) -> (getBalance(n.0, n.1, s), s)
  | GetTotalSupply(n) -> (getTotalSupply(n.1, s), s)
  | Mint(n) -> ((nil : list(operation)), mint(n, s))
  | Burn(n) -> (burn(n.0,n.1,n.2,s))
 end