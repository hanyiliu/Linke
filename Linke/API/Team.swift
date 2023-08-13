//
//  Team.swift
//  Linke
//
//  Created by Hanyi Liu on 6/6/23.
//

import Foundation
import FirebaseFirestore
import GoogleSignIn
class Team: ObservableObject {
    @Published var teamCode = "" {
        willSet(value) {
            Task {
                do {
                    teamDictionary = try await fetchTeamData(teamCode: value)
                    UpdateValue.saveToLocal(key: "TEAM_CODE", value: value)
                } catch {
                    print("Error trying to initialize team dictionary: \(error)")
                }
            }
        }
    }
    @Published var teamDictionary: [String: Any]?
    @Published var founderName = ""
    @Published var toggle = true
    
    static let db = Firestore.firestore()
    
    init() {
        if let teamCode = UpdateValue.loadFromLocal(key: "TEAM_CODE", type: "String") as? String {
            print("Found existing team code: \(teamCode)")
            self.teamCode = teamCode
        } else {
            print("Trying to find if student is part of team online.")
            guard let studentID = GIDSignIn.sharedInstance.currentUser?.userID else { return }
            let teamDataRef = Firestore.firestore().collection("team_data")
            let query = teamDataRef.whereField("students", arrayContains: studentID)
            Task {
                do {
                    let snapshot = try await query.getDocuments()
                    guard let document = snapshot.documents.first else {
                        print("Document not found")
                        return
                    }
                    print("Student already part of team online. Loading team.")
                    teamDictionary = document.data()
                    teamCode = teamDictionary!["student_code"] as? String ?? ""
                    
                } catch {
                    print("Error getting document: \(error)")
                }
            }
        }
    }
    ///Return team dictionary from Firebase.
    func fetchTeamData(teamCode: String) async throws -> [String: Any]? {
        
        let teamsCollection = Team.db.collection("team_data")

        // Query the collection to find the document with matching team_code
        let querySnapshot = try await teamsCollection.whereField("student_code", isEqualTo: teamCode).getDocuments()

        // Check if any documents were found
        guard let document = querySnapshot.documents.first else {
            print("No team document found with team_code: \(teamCode)")
            
            return nil
        }
        
        appendStudentID(document: document.reference)
        UpdateValue.saveToLocal(key: "TEAM_CODE", value: teamCode)
        
        // Convert the document data to [String: Any] dictionary
        let dictionary = document.data()
        toggle.toggle()
        print("Successfully loaded team dictionary.")
        return dictionary
    }
    
    ///Refresh team
    func refreshTeam() {
        guard teamCode != "" else { return }
        Task {
            do {
                teamDictionary = try await fetchTeamData(teamCode: teamCode)
                
            } catch {
                print("Error trying to initialize team dictionary: \(error)")
            }
        }
    }
    
    ///Leave team.
    func leaveTeam() {
        guard teamDictionary != nil else {
            print("No team dictionary")
            return
        }
        let document = Team.db.collection("team_data").document(teamDictionary!["id"] as! String)
        removeStudentID(document: document)
        clearLocalTeamData()
        toggle.toggle()
    }
    
    ///Add student's iD to the team document's students array.
    func appendStudentID(document: DocumentReference) {
        guard let id = GIDSignIn.sharedInstance.currentUser?.userID else {
            print("No student ID found.")
            return
        }
        
        document.updateData(["students": FieldValue.arrayUnion([id])]) { error in
            if let error = error {
                print("Error appending ID to students array: \(error)")
            } else {
                print("ID appended to students array successfully")
            }
        }
    }
    
    ///Remove student's iD from the team document's students array.
    func removeStudentID(document: DocumentReference) {
        guard let id = GIDSignIn.sharedInstance.currentUser?.userID else {
            print("No student ID found.")
            return
        }
        
        document.updateData(["students": FieldValue.arrayRemove([id])]) { error in
            if let error = error {
                print("Error removing ID from students array: \(error)")
            } else {
                print("ID removed from students array successfully")
            }
        }
    }
    
    /// Function to fetch the founder's name based on the founderID\
    func fetchFounderName() async {
        guard let founderID = teamDictionary!["team_founder"] as? String else {
            print("No team dictionary.")
            return
        }
        let db = Firestore.firestore()
        let adminCollection = db.collection("admin_data")

        do {
            // Fetch the document with matching founderID
            let document = try await adminCollection.document(founderID).getDocument()

            // Check if the document exists
            guard document.exists else {
                print("Founder document not found for ID: \(founderID)")
                return
            }

            // Retrieve the name field from the document
            if let name = document.data()?["name"] as? String {
                DispatchQueue.main.async {
                    self.founderName = name
                }
            } else {
                print("Error retrieving founder's name")
            }
        } catch {
            print("Error fetching founder's name: \(error)")
        }
    }
    
    ///Clear local team data
    func clearLocalTeamData() {
        teamCode = ""
        teamDictionary = nil
        founderName = ""
        UpdateValue.saveToLocal(key: "TEAM_CODE", value: "")
    }
    
 }
