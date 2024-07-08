import Foundation

struct ScaffoldGenerator {
    let name: String
    let fields: [String: String]

    init(name: String, fields: [String: String]) {
        self.name = name
        self.fields = fields
    }

    func generate( ) throws {
         try generateModel(name: name, fields: fields)
         try generateController(name: name, fields: fields)
         try generateMigration(name: name, fields: fields)
         try generateViews(name: name, fields: fields)
        //try updateRoutes(name: name)
    }

    private func generateModel(name: String, fields: [String: String]) throws {
           let fieldsDefinition = fields.map { field, type in
               "@Field(key: \"\(field)\") var \(field): \(type)"
           }.joined(separator: "\n    ")

           let initParameters = fields.map { field, type in
               "\(field): \(type)"
           }.joined(separator: ", ")

           let initAssignments = fields.map { field, type in
               "self.\(field) = \(field)"
           }.joined(separator: "\n        ")

           let modelContent = """
           import Vapor
           import Fluent

           final class \(name): Model, Content {
               static let schema = "\(name.lowercased())s"

               @ID(key: .id)
               var id: UUID?

               \(fieldsDefinition)

               init() { }

               init(id: UUID? = nil, \(initParameters)) {
                   self.id = id
                   \(initAssignments)
               }
           }
           """
           try writeFile(content: modelContent, to: "Sources/App/Models/\(name).swift")
       }
    private func generateController(name: String, fields: [String: String]) throws {
            let fieldsAssignment = fields.map { field, type in
                "\(name.lowercased()).\(field) = try req.content.get(\(type).self, at: \"\(field)\")"
            }.joined(separator: "\n        ")

            let controllerContent = """
            import Vapor
            import Fluent

            final class \(name)Controller: RouteCollection {
                func boot(routes: RoutesBuilder) throws {
                    let \(name.lowercased())sRoute = routes.grouped("\(name.lowercased())s")
                    \(name.lowercased())sRoute.get(use: index)
                    \(name.lowercased())sRoute.post(use: create)
                    \(name.lowercased())sRoute.group(":id") { \(name.lowercased()) in
                        \(name.lowercased()).get(use: show)
                        \(name.lowercased()).put(use: update)
                        \(name.lowercased()).delete(use: delete)
                    }
                }

                func index(req: Request) throws -> EventLoopFuture<[\(name)]> {
                    return \(name).query(on: req.db).all()
                }

                func create(req: Request) throws -> EventLoopFuture<\(name)> {
                    let \(name.lowercased()) = try req.content.decode(\(name).self)
                    return \(name.lowercased()).save(on: req.db).map { \(name.lowercased()) }
                }

                func show(req: Request) throws -> EventLoopFuture<\(name)> {
                    return \(name).find(req.parameters.get("id"), on: req.db)
                        .unwrap(or: Abort(.notFound))
                }

                func update(req: Request) throws -> EventLoopFuture<HTTPStatus> {
                    return \(name).find(req.parameters.get("id"), on: req.db)
                        .unwrap(or: Abort(.notFound)).flatMap { \(name.lowercased()) in
                            \(fieldsAssignment)
                            return \(name.lowercased()).save(on: req.db).transform(to: .ok)
                        }
                }

                func delete(req: Request) throws -> EventLoopFuture<HTTPStatus> {
                    return \(name).find(req.parameters.get("id"), on: req.db)
                        .unwrap(or: Abort(.notFound))
                        .flatMap { \(name.lowercased()) in
                            return \(name.lowercased()).delete(on: req.db).transform(to: .ok)
                        }
                }
            }
            """
            try writeFile(content: controllerContent, to: "Sources/App/Controllers/\(name)Controller.swift")
        }

        private func generateMigration(name: String, fields: [String: String]) throws {
            let fieldsDefinition = fields.map { field, type in
                ".field(\"\(field)\", .\(type.lowercased()), .required)"
            }.joined(separator: "\n            ")

            let migrationContent = """
            import Fluent

            struct Create\(name): Migration {
                func prepare(on database: Database) -> EventLoopFuture<Void> {
                    return database.schema("\(name.lowercased())s")
                        .id()
                        \(fieldsDefinition)
                        .create()
                }

                func revert(on database: Database) -> EventLoopFuture<Void> {
                    return database.schema("\(name.lowercased())s").delete()
                }
            }
            """
            try writeFile(content: migrationContent, to: "Sources/App/Migrations/Create\(name).swift")
        }

        private func generateViews(name: String, fields: [String: String]) throws {
            let indexViewContent = """
            #extend("base") {
                #export("title") { \(name) Index }
                #export("body") {
                    <h1>\(name) Index</h1>
                    <ul>
                        #for(\(name.lowercased()) in \(name.lowercased())s) {
                            <li>#(\(name.lowercased()).name)</li>
                        }
                    </ul>
                }
            }
            """
            try writeFile(content: indexViewContent, to: "Resources/Views/\(name.lowercased())s/index.leaf")

            let createFormFields = fields.map { field, type in
                """
                <label for="\(field)">\(field.capitalized):</label>
                <input type="text" id="\(field)" name="\(field)">
                """
            }.joined(separator: "\n            ")

            let createViewContent = """
            #extend("base") {
                #export("title") { Create \(name) }
                #export("body") {
                    <h1>Create \(name)</h1>
                    <form action="/\(name.lowercased())s" method="post">
                        \(createFormFields)
                        <button type="submit">Create</button>
                    </form>
                }
            }
            """
            try writeFile(content: createViewContent, to: "Resources/Views/\(name.lowercased())s/create.leaf")
        }

        private func updateRoutes(name: String) throws {
            let routesFilePath = "Sources/App/routes.swift"
            let routesFileURL = URL(fileURLWithPath: routesFilePath)
            var routesContent = try String(contentsOf: routesFileURL)

            let importStatement = "import Vapor\n"
            let controllerImport = "import \(name)Controller\n"
            let controllerRoute = "    try app.register(collection: \(name)Controller())\n"

            if !routesContent.contains(controllerImport) {
                routesContent = routesContent.replacingOccurrences(of: importStatement, with: importStatement + controllerImport)
            }

            if !routesContent.contains(controllerRoute) {
                routesContent += "\n\(controllerRoute)"
            }

            try writeFile(content: routesContent, to: routesFilePath)
        }

        private func writeFile(content: String, to path: String) throws {
            let fileURL = URL(fileURLWithPath: path)
            let directory = fileURL.deletingLastPathComponent()

            if !FileManager.default.fileExists(atPath: directory.path) {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            }

            try content.write(to: fileURL, atomically: true, encoding: .utf8)
        }
}
