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
        const img = new Image();
        img.onload = () => {
            try {
                const canvas = document.createElement('canvas');
                canvas.width = img.width;
                canvas.height = img.height;
                const ctx = canvas.getContext('2d');
                ctx.drawImage(img, 0, 0);
                
                const imgData = ctx.getImageData(0, 0, canvas.width, canvas.height);
                const data = imgData.data;
                
                let minX = canvas.width, minY = canvas.height, maxX = 0, maxY = 0;
                
                for (let y = 0; y < canvas.height; y++) {
                    for (let x = 0; x < canvas.width; x++) {
                        const alpha = data[(y * canvas.width + x) * 4 + 3];
                        if (alpha > 5) { // 약간의 투명도 임계값
                            if (x < minX) minX = x;
                            if (x > maxX) maxX = x;
                            if (y < minY) minY = y;
                            if (y > maxY) maxY = y;
                        }
                    }
                }
                
                // 완전히 투명한 이미지이거나 에러 방지
                if (minX > maxX || minY > maxY) {
                    resolve(canvas.toDataURL('image/png'));
                    return;
                }
                
                // 패딩 없이 정확히 바운딩 박스 크기만큼 잘라내기
                const width = maxX - minX + 1;
                const height = maxY - minY + 1;
                
                const croppedCanvas = document.createElement('canvas');
                croppedCanvas.width = width;
                croppedCanvas.height = height;
                const croppedCtx = croppedCanvas.getContext('2d');
                croppedCtx.drawImage(
                    canvas,
                    minX, minY, width, height,
                    0, 0, width, height
                );
                
                resolve(croppedCanvas.toDataURL('image/png'));
            } catch (e) {
                reject(e);
            }
        };
        img.onerror = reject;
        img.src = URL.createObjectURL(blob);
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
