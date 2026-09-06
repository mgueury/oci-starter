const status = document.getElementById('status');
const serviceDescription = document.getElementById('service-description');
const serviceDetails = document.getElementById('service-details');

async function loadRest() {
  status.className = 'status';
  status.innerHTML = '<span class="status-dot"></span>Checking service status…';
  try {
    const [departmentsResult, infoResult] = await Promise.allSettled([
      fetch('app/dept'),
      fetch('app/info')
    ]);
    if (infoResult.status !== 'fulfilled' || !infoResult.value.ok) throw new Error('Service information unavailable');

    const info = parseServiceInfo(await infoResult.value.text());
    serviceDescription.textContent = renderServiceDescription(info);
    document.getElementById('info').textContent = 'Service available';
    renderServiceDetails(info);
    status.className = 'status connected';
    status.innerHTML = '<span class="status-dot"></span>Service available';

    if (departmentsResult.status !== 'fulfilled' || !departmentsResult.value.ok) throw new Error('Department data unavailable');
    json2table(await departmentsResult.value.json());
  } catch (error) {
    if (error.message === 'Service information unavailable') {
      serviceDescription.textContent = 'Service information could not be retrieved.';
      document.getElementById('info').textContent = 'Service status unavailable';
      serviceDetails.replaceChildren();
      status.className = 'status error';
      status.innerHTML = '<span class="status-dot"></span>Service unavailable';
    }
    document.getElementById('table').innerHTML = '<div class="loading">Unable to load department data. Please try again.</div>';
  }
}

function parseServiceInfo(value) {
  const [deploy, database, language, framework, ip] = value
    .split(' - ')
    .map((part) => part.trim());
  return { deploy, database, language, framework, ip };
}

function renderServiceDescription(info) {
  const values = {
    language: info.language || 'application',
    deploy: info.deploy || 'platform',
    database: info.database || 'data source'
  };
  return serviceDescription.dataset.template.replace(
    /\{(language|deploy|database)\}/g,
    (_match, key) => values[key]
  );
}

function renderServiceDetails(info) {
  const details = [
    ['Deployment', info.deploy],
    ['Database', info.database],
    ['Language', info.language],
    ['Framework', info.framework],
    ['IP', info.ip]
  ].filter(([, value]) => value);

  serviceDetails.replaceChildren(...details.map(([label, value]) => {
    const wrapper = document.createElement('div');
    const term = document.createElement('dt');
    const description = document.createElement('dd');
    term.textContent = label;
    description.textContent = value;
    wrapper.append(term, description);
    return wrapper;
  }));
}

function json2table(rows) {
  const container = document.getElementById('table');
  if (!rows.length) { container.innerHTML = '<div class="loading">No departments found.</div>'; return; }
  const columns = Object.keys(rows[0]);
  const table = document.createElement('table');
  const header = table.insertRow();
  columns.forEach((column) => { const cell = document.createElement('th'); cell.textContent = column; header.appendChild(cell); });
  rows.forEach((row) => { const tr = table.insertRow(); columns.forEach((column) => { const cell = tr.insertCell(); cell.textContent = row[column] ?? ''; }); });
  container.replaceChildren(table);
}

document.getElementById('refresh').addEventListener('click', loadRest);
loadRest();
