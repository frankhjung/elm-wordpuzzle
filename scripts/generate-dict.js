const fs = require('fs');
const path = require('path');

const txtPath = path.join(__dirname, '../static/dictionary');
const jsPath = path.join(__dirname, '../static/dictionary.js');

const content = fs.readFileSync(txtPath, 'utf8');
fs.writeFileSync(jsPath, `window.WORDPUZZLE_DICTIONARY = ${JSON.stringify(content)};\n`);
console.log(`Generated ${jsPath} (${content.length} characters)`);
