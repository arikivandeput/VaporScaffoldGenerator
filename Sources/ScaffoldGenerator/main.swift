import Foundation

func main() {
    let arguments = CommandLine.arguments

    guard arguments.count > 2 else {
        print("Usage: scaffold <name> <field:type> [<field:type>...]")
        return
    }

    let name = arguments[1]
    let fields = arguments[2...].reduce(into: [String: String]()) { result, argument in
        let parts = argument.split(separator: ":")
        if parts.count == 2 {
            result[String(parts[0])] = String(parts[1])
        }
    }

    let generator = ScaffoldGenerator(name: name, fields: fields)

    do {
        try generator.generate()
        print("Scaffold generated successfully for \(name).")
    } catch {
        print("Error generating scaffold: \(error)")
    }
}

main()
