const dirTree = require("directory-tree");
const { execSync } = require('child_process');


function flatDirTree(tree) {
  return tree.children.reduce((acc, current) => {
    if (current.children === undefined) {
      return [
        ...acc,
        current,
      ];
    }
    
    const flatChild = flatDirTree(current);
    
    return [...acc, ...flatChild];
  }, []);
}


// Compile all the sources
// - Get all .sol sources
const contractsNestedTree = dirTree(
  "contracts",
  { extensions: /\.sol/ }
);
const contractsTree = flatDirTree(contractsNestedTree);

console.log(`Compiling ${contractsTree.length} sources`);

try {
// - Prepare each source
  contractsTree.map(({ path }) => {
    console.debug(`Compile ${path}`);
    
    const [,contractFileName] = path.match(new RegExp('contracts/(.*).sol'));
    
    const output = execSync(`cd build && solc-ton ./../${path}`);
    
    if (output.toString() === '') {
      // No code was compiled, probably interface compilation
      return;
    }
    
    const contractNameNoFolderStructure = contractFileName.split('/')[contractFileName.split('/').length - 1];
    
    const tvmLinkerLog = execSync(`cd build && tvm_linker compile "${contractNameNoFolderStructure}.code" -a "${contractNameNoFolderStructure}.abi.json"`);
    const [,tvcFile] = tvmLinkerLog.toString().match(new RegExp('Saved contract to file (.*)'));
    execSync(`cd build && base64 < ${tvcFile} > ${contractNameNoFolderStructure}.base64`);
    
    execSync(`cd build && mv ${tvcFile} ${contractNameNoFolderStructure}.tvc`);
  });
} catch (e) {
}
