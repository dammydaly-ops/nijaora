// Quick read-only check for the Nijaora Supabase project.
//
// Usage (PowerShell):
//   $env:SUPABASE_URL="https://jipythusnrclazfjkkqp.supabase.co"
//   $env:SUPABASE_ANON_KEY="sb_publishable_..."
//   node scripts/check_supabase.mjs
//
// Uses only the publishable/anon key. Never put a service_role key here.

const url = process.env.SUPABASE_URL?.replace(/\/$/, '');
const key = process.env.SUPABASE_ANON_KEY;

if (!url || !key) {
  console.error('Set SUPABASE_URL and SUPABASE_ANON_KEY first.');
  process.exit(1);
}

const headers = {
  apikey: key,
  Authorization: `Bearer ${key}`,
};

async function count(table) {
  const response = await fetch(`${url}/rest/v1/${table}?select=id`, {
    headers: {
      ...headers,
      Prefer: 'count=exact',
      Range: '0-0',
    },
  });
  if (!response.ok) {
    throw new Error(`${table}: HTTP ${response.status} ${await response.text()}`);
  }
  const range = response.headers.get('content-range') ?? '';
  const total = range.includes('/') ? range.split('/')[1] : '?';
  return total;
}

const tables = [
  'states',
  'lgas',
  'neighbourhoods',
  'categories',
  'businesses',
  'listings',
];

let failed = false;
for (const table of tables) {
  try {
    console.log(`${table.padEnd(16)} ${await count(table)}`);
  } catch (error) {
    failed = true;
    console.error(error.message);
  }
}

if (failed) {
  console.error(
    '\nOne or more tables are unavailable. If the tables exist but the API ' +
      'returns permission denied, run ' +
      'supabase/migrations/20261027000300_grants.sql. Otherwise apply the ' +
      'migrations in supabase/migrations, then run this check again.',
  );
  process.exit(1);
}

console.log('\nReference counts should be 37 states, 774 LGAs, 27 neighbourhoods and 156 categories.');
