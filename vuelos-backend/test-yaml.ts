import fs from 'fs';
import path from 'path';
import yaml from 'js-yaml';

try {
  const catalogPath = path.resolve('openapi-catalog.yaml');
  const catalogContent = fs.readFileSync(catalogPath, 'utf8');
  const catalogDoc = yaml.load(catalogContent) as any;
  console.log('✅ Loaded openapi-catalog.yaml. Title:', catalogDoc.info.title);
} catch (e: any) {
  console.error('❌ Failed:', e.message);
}
