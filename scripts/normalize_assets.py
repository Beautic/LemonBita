import os
import unicodedata

def normalize_nfc(directory):
    for filename in os.listdir(directory):
        normalized = unicodedata.normalize('NFC', filename)
        if normalized != filename:
            old_path = os.path.join(directory, filename)
            new_path = os.path.join(directory, normalized)
            # 만약 이미 NFC 경로에 파일이 존재한다면 삭제 후 덮어쓰거나 무시
            if os.path.exists(new_path):
                os.remove(old_path)
                print(f"Removed duplicate NFD file: {filename}")
            else:
                os.rename(old_path, new_path)
                print(f"Normalized: {filename} -> {normalized}")

if __name__ == "__main__":
    icon_dir = "/Users/a421104/Documents/project/Antigravity/dress/assets/icons"
    normalize_nfc(icon_dir)
