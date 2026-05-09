let _libPromise = null;

function _loadLib() {
    if (!_libPromise) {
        _libPromise = import('https://cdn.jsdelivr.net/npm/@imgly/background-removal/+esm')
            .then(mod => mod.removeBackground)
            .catch(err => {
                _libPromise = null;
                throw err;
            });
    }
    return _libPromise;
}

_loadLib();

window.removeImageBackground = async function(base64Image) {
    const removeBackground = await _loadLib();
    const blob = await removeBackground(base64Image);
    return new Promise((resolve, reject) => {
        const reader = new FileReader();
        reader.onloadend = () => resolve(reader.result);
        reader.onerror = reject;
        reader.readAsDataURL(blob);
    });
};

window.flattenImageToJpeg = async function(dataUrl) {
    return new Promise((resolve, reject) => {
        const img = new Image();
        img.crossOrigin = 'anonymous';
        img.onload = () => {
            try {
                const canvas = document.createElement('canvas');
                canvas.width = img.naturalWidth || img.width;
                canvas.height = img.naturalHeight || img.height;
                const ctx = canvas.getContext('2d');
                ctx.fillStyle = '#FFFFFF';
                ctx.fillRect(0, 0, canvas.width, canvas.height);
                ctx.drawImage(img, 0, 0);
                resolve(canvas.toDataURL('image/jpeg', 0.95));
            } catch (e) {
                reject(e);
            }
        };
        img.onerror = () => reject(new Error('image decode failed'));
        img.src = dataUrl;
    });
};
