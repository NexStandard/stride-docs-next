function addVersionNavigation() {
    const version = document.getElementById("toc");
    const selectHtml = `
        <select id="stride-current-version" class="form-select" aria-label="Default select example">
            <option selected>Latest</option>
        </select>
    `;
    version.insertAdjacentHTML("afterbegin", selectHtml);
}

function loadVersions() {
    fetch('/versions.json')
        .then(response => response.json())
        .then(data => {
            const selectElement = document.getElementById("stride-current-version");
            selectElement.innerHTML = '';

            // Add the "Latest" option
            const latestOption = document.createElement('option');
            latestOption.value = 'latest';
            latestOption.textContent = 'Latest';
            selectElement.appendChild(latestOption);

            data.versions.forEach(version => {
                const url = version;
                const option = document.createElement('option');
                option.value = url;
                option.textContent = version;
                selectElement.appendChild(option);
            });

            const urlSplits = window.location.pathname.split('/');
            let urlVersion = urlSplits[1];
            //if (urlVersion === 'latest') {
            //    urlVersion = data.versions[0];
            //}

            selectElement.value = urlVersion;
            selectElement.dispatchEvent(new Event('change'));
            redirectToCurrentDocVersion();
        });
}

function redirectToCurrentDocVersion() {
    const selectElement = document.getElementById('stride-current-version');
    selectElement.addEventListener('change', function () {
        const hostVersion = window.location.host;
        const pathVersion = window.location.pathname;
        const targetVersion = selectElement.value;

        // Generate page URL in other version
        let newAddress = '//' + hostVersion + '/' + targetVersion + '/' + pathVersion.substring(pathVersion.indexOf('/', 1) + 1);

        // Check if address exists
        fetch(newAddress, { method: 'HEAD' })
            .then(response => {
                if (!response.ok) {
                    // It didn't work, let's just go to the top page of the section (i.e. manual, api, release notes, etc.)
                    newAddress = '//' + hostVersion + '/' + targetVersion + '/' + pathVersion.split('/')[2];
                    if (pathVersion.split('/').length >= 4) {
                        newAddress += '/' + pathVersion.split('/')[3];
                    }
                }
            })
            .catch(error => {
                console.error('Error checking URL:', error);
            })
            .finally(() => {
                // Go to page
                window.location.href = newAddress;
            });
    });
}


function start() {

    addVersionNavigation()
    loadVersions();
}

document.addEventListener("DOMContentLoaded", start);