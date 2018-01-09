var fs = require('fs');
var path = require('path');

var vsixVersionFile = '../Tasks/tfs-scan-executor/task.json';
var vsixVersionJson = require(vsixVersionFile);

vsixVersionJson.version.Patch = (parseInt(vsixVersionJson.version.Patch) + 1).toString();

fs.writeFileSync(path.join(__dirname, vsixVersionFile), JSON.stringify(vsixVersionJson, null, 2));