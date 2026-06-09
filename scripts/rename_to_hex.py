import os
import unicodedata

def rename_to_hex(directory):
    for filename in os.listdir(directory):
        if not filename.endswith('.png'):
            continue
            
        base, ext = os.path.splitext(filename)
        # NFC로 정규화하여 일관성 확보
        base_nfc = unicodedata.normalize('NFC', base)
        
        # 각 문자의 유니코드 값을 16진수 문자열로 변환
        hex_parts = [f"{ord(char):04x}" for char in base_nfc]
        new_name = "_".join(hex_parts) + ext
        
        old_path = os.path.join(directory, filename)
        new_path = os.path.join(directory, new_name)
        
        if old_path != new_path:
            # 기존 hex 파일이 있다면 지우고 덮어씀
            if os.path.exists(new_path):
                os.remove(old_path)
                print(f"Removed redundant/original: {filename}")
            else:
                os.rename(old_path, new_path)
                print(f"Renamed: {filename} -> {new_name}")

if __name__ == "__main__":
    icon_dir = "/Users/a421104/Documents/project/Antigravity/dress/assets/icons"
    rename_to_hex(icon_dir)
