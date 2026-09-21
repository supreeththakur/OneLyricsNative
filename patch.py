import sys

def patch():
    file_path = "/Users/itech/Documents/OneLyricsNative/Sources/OneLyrics/Utils/VideoExporter.swift"
    replacement_path = "/Users/itech/Documents/OneLyricsNative/replacement.swift"
    
    with open(file_path, "r") as f:
        original = f.readlines()
        
    with open(replacement_path, "r") as f:
        replacement = f.readlines()
        
    start_idx = -1
    end_idx = -1
    for i, line in enumerate(original):
        if "// 3. Start Audio Appending concurrently" in line:
            start_idx = i
        if "class VideoFrameReader {" in line:
            end_idx = i
            break
            
    if start_idx == -1 or end_idx == -1:
        print("Could not find indices")
        return
        
    # We want to replace from start_idx up to the end of the exportVideo function.
    # The exportVideo function ends with:
    #             } catch {
    #                 DispatchQueue.main.async {
    #                     self.exportError = error.localizedDescription
    #                     self.isExporting = false
    #                 }
    #             }
    #         }
    #     }
    # }
    # So it's end_idx - 1
    
    print(f"Replacing from line {start_idx + 1} to {end_idx}")
    new_content = original[:start_idx] + replacement + original[end_idx-1:]
    
    with open(file_path, "w") as f:
        f.writelines(new_content)
        
    print("Patch applied successfully")

if __name__ == "__main__":
    patch()
