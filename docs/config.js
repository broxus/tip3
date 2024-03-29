const path = require('path');
const fs = require('fs');

module.exports = {
  outputDir: 'docs/modules/api/pages',
  sourcesDir: 'contracts',
  templates: 'docs/templates',
  exclude: ['tests'],
  pageExtension: '.adoc',
  pages: (_, file, config) => {
    // For each contract file, find the closest README.adoc and return its location as the output page path.
    const sourcesDir = path.resolve(config.root, config.sourcesDir);
    let dir = path.resolve(config.root, file.absolutePath);

    while (dir.startsWith(sourcesDir)) {
      dir = path.dirname(dir);
      if (fs.existsSync(path.join(dir, 'README.adoc'))) {
        return path.relative(sourcesDir, dir) + config.pageExtension;
      }
    }
  },
};
