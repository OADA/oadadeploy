module.exports = {
  redirect_uris: ['https://test.example.com/oadaauth/id-redirect'],
  token_endpoint_auth_method:
    'urn:ietf:params:oauth:client-assertion-type:jwt-bearer',
  grant_types: ['authorization_code'],
  response_types: [
    'token',
    'code',
    'id_token',
    'id_token token',
    'code id_token',
    'code token',
    'code id_token token'
  ],
  client_name: 'Test example.com',
  client_uri: 'https://test.example.com',
  contacts: ['Aaron Ault <aultac@purdue.edu>'],
  jwks: {
    keys: [
      {
       "kty":"RSA",
       "n":"scWX1uAofN3j3b-ddyqb35wpIErOIP4aqWQaR-ZiNmU8zGiU_Kdn6_GrEZSFUZJQ7o2H2HAxf5_Q6ohQTQrRihAId4wn4eq8lOym-GGo0KFezqVMuVo7pY1VjYDVOi4Nhz3Xg_Y_B5EBhL0C7wXzvcukZgIDhTQT1DuCuHAyPbkEzx4liXyqCwo251q4MsHIalXhRH-RQ5M4Omq2p_SoscM8Aixnt_797RL__nm663njw49t8kvcJg-32-eHheuropccz-5C6kkg3wf1CYb9jwbpJRBmUnkHPy2ZzoSUdEZX-9FQoyupE-HSFzl3rDy7vI77nnNExW3IUeWF-g4VFw",
       "e":"AQAB",
       "kid":"ffc3b5b48c05497484af245f0435373a"
      }
    ]
  }
}