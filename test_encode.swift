import Foundation

struct ProjectState: Codable {
    var title: String = "Untitled Project"
    
    init() {}
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? "Untitled Project"
    }
}

var p = ProjectState()
p.title = "arz kiya hai"
let data = try! JSONEncoder().encode(p)
print(String(data: data, encoding: .utf8)!)
