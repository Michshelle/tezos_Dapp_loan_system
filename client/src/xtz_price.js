

//async function xtz_price() {
//   const fetch = require('node-fetch') 
//   const url = 'https://api-pub.bitfinex.com/v2/'
//    
//   const pathParams = 'ticker/tXTZUSD' // Change these based on relevant path params
//   const queryParams = '' // Change these based on relevant query params
//   let v;
//   try {
//       const req = await fetch(`${url}/${pathParams}?${queryParams}`)
//       const response = await req.json()
//       v = Number(response[0])    
//   }
//   catch (err) {
//       console.log(err)
//   }
//   return v;
//}
//
//console.log(xtz_price());

//const url = 'https://api-pub.bitfinex.com/v2/'
const url = 'http://localhost:3001/v2'
const pathParams = 'ticker/tXTZUSD' // Change these based on relevant path params
const queryParams = '' // Change these based on relevant query params

async function request() {
   try {
       
       const fetch = require('node-fetch') 
       const req = await fetch(`${url}/${pathParams}?${queryParams}`)
       const response = await req.json()
       let v = response[0]
       console.log(v)
       return v

       
   }
   catch (err) {
       console.log(err)
   }
}

request()

