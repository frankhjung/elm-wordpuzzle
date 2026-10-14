const fs = require('fs');
const { execFileSync } = require('child_process');
const path = require('path');

const candidateBins = [
  process.env.HASKELL_BIN,
  '/home/frank/dev/haskell/wordpuzzle/dist-newstyle/build/x86_64-linux/ghc-9.6.7/wordpuzzle-1.1.1/x/wordpuzzle/build/wordpuzzle/wordpuzzle'
].filter(Boolean);

const haskellBin = candidateBins.find(p => fs.existsSync(p));
if (!haskellBin) {
  console.error("Haskell binary not found. Set HASKELL_BIN environment variable.");
  process.exit(1);
}

const workerJs = path.join(__dirname, '../elm-stuff/parity-worker.js');
execFileSync('elm', ['make', 'tests/ParityWorker.elm', '--output=' + workerJs], { stdio: 'inherit' });

const { Elm } = require(workerJs);
const dictionary = fs.readFileSync(path.join(__dirname, '../static/dictionary.txt'), 'utf8');

function solveElm(size, mandatory, letters, repeats) {
  return new Promise((resolve) => {
    const app = Elm.ParityWorker.init({
      flags: { dictionary, size, mandatory, letters, repeats }
    });
    app.ports.toNode.subscribe((words) => {
      resolve(words);
    });
  });
}

function solveHaskell(size, mandatory, letters, repeats) {
  const args = ['-s', String(size), '-m', mandatory, '-l', letters, '-d', path.join(__dirname, '../static/dictionary.txt')];
  if (repeats) {
    args.push('-r');
  }
  const res = execFileSync(haskellBin, args, { encoding: 'utf8' });
  return res.split(/\r?\n/).map(w => w.trim()).filter(Boolean);
}

const testCases = [
  { size: 7, mandatory: 'c', letters: 'cadevrsoi', repeats: false, label: 'Nine-letter word (size 7, repeats off)' },
  { size: 6, mandatory: 'c', letters: 'cadevrsoi', repeats: false, label: 'Nine-letter word (size 6, repeats off)' },
  { size: 4, mandatory: 'm', letters: 'mitncao', repeats: true, label: 'Spelling Bee mitncao (repeats on)' },
  { size: 5, mandatory: 'a', letters: 'abcdefghi', repeats: false, label: 'Full 9-letter pool (repeats off)' },
  { size: 4, mandatory: 'p', letters: 'pzleout', repeats: true, label: 'Spelling Bee pzleout (repeats on)' },
  { size: 9, mandatory: 'c', letters: 'cadevrsoi', repeats: false, label: 'Nine-letter words only (size 9)' }
];

async function run() {
  console.log(`Using Haskell binary: ${haskellBin}`);
  let allPassed = true;

  for (const tc of testCases) {
    process.stdout.write(`Testing: ${tc.label}... `);
    const haskellWords = solveHaskell(tc.size, tc.mandatory, tc.letters, tc.repeats).sort();
    const elmWords = (await solveElm(tc.size, tc.mandatory, tc.letters, tc.repeats)).sort();

    if (JSON.stringify(haskellWords) === JSON.stringify(elmWords)) {
      console.log(`PASS (${elmWords.length} words matched)`);
    } else {
      console.log(`FAIL!`);
      console.error(`Haskell count: ${haskellWords.length}, Elm count: ${elmWords.length}`);
      const hSet = new Set(haskellWords);
      const eSet = new Set(elmWords);
      const inHaskellOnly = haskellWords.filter(w => !eSet.has(w));
      const inElmOnly = elmWords.filter(w => !hSet.has(w));
      if (inHaskellOnly.length > 0) {
        console.error(`In Haskell only:`, inHaskellOnly.slice(0, 10));
      }
      if (inElmOnly.length > 0) {
        console.error(`In Elm only:`, inElmOnly.slice(0, 10));
      }
      allPassed = false;
    }
  }

  if (!allPassed) {
    process.exit(1);
  }
  console.log(`\nAll parity test cases passed with 100% exact match!`);
}

run();
