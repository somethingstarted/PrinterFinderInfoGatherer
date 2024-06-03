document.addEventListener('DOMContentLoaded', () => {
    fetch('/foundprinters/printers_2024-05.csv')
        .then(response => response.text())
        .then(data => {
            const filename = 'printers_2024-05.csv';
            document.getElementById('filename').innerText = filename;

            const rows = data.split('\n').map(row => row.split(','));
            let table = '<table border="1">';
            rows.forEach(row => {
                table += '<tr>';
                row.forEach(cell => {
                    if (isValidIP(cell)) {
                        table += `<td><a href="http://${cell}" target="_blank">${cell}</a></td>`;
                    } else {
                        table += `<td>${cell}</td>`;
                    }
                });
                table += '</tr>';
            });
            table += '</table>';
            document.getElementById('csvTable').innerHTML = table;
        });
});

function isValidIP(str) {
    const pattern = /^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$/;
    return pattern.test(str);
}
