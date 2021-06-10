module.exports = {
  domain: '{{DOMAIN}}', // just here for informational purposes
  baseuri: 'https://{{DOMAIN}}', // just here for informational purposes
  logo: '{{LOGO}}',
  name: '{{NAME}}',
  tagline: '',
  color: '#FFFFFF',
  hint: {
    username: '',
    password: ''
  },
  idService: {
    shortname: 'OADA',
    longname: 'Open Ag Data Alliance'
  },

  // To generate keys:
  // 1: create key pair: openssl genrsa -out private_key.pem 2048
  // 2: extract public key: openssl rsa -pubout -in private_key.pem -out public_key.pem
  keys: {
    public: 'public_key.pem',
    private: {
      // Use the first (and only) key in software statement:
      kid: require('./unsigned_software_statement').jwks.keys[0].kid,
      // Read the private key from the private key file:
      pem: require('fs').readFileSync(__dirname + '/private_key.pem').toString()
    }
  },
  unsigned_software_statement: require('./unsigned_software_statement.js'),
  software_statement: require('./signed_software_statement.js')
}
