import HashMap "mo:base/HashMap";
import Text "mo:base/Text";
import Time "mo:base/Time";
import Principal "mo:base/Principal";
import Error "mo:base/Error";
import Result "mo:base/Result";
import Array "mo:base/Array";
import Iter "mo:base/Iter";
import Debug "mo:base/Debug";
import Option "mo:base/Option";  // Added this import

actor DeVault {
  // Define the document structure
  public type Document = {
    hash: Text;
    fileName: Text;
    uploadedBy: Principal;
    uploadedAt: Time.Time;
  };

  // Define error types for better error handling
  public type Error = {
    #AlreadyExists: Text;
    #NotFound: Text;
    #NotAuthorized: Text;
  };

  // Use stable var for persistence across upgrades
  private stable var documentsEntries : [(Text, Document)] = [];
  
  // Internal store to keep documents by their hash
  private var documents = HashMap.HashMap<Text, Document>(
    0, Text.equal, Text.hash
  );
  
  // System initialization
  system func preupgrade() {
    // Prepare data for upgrade
    documentsEntries := Iter.toArray(documents.entries());
  };

  system func postupgrade() {
    // Restore data after upgrade
    documents := HashMap.fromIter<Text, Document>(
      documentsEntries.vals(),
      documentsEntries.size(),
      Text.equal,
      Text.hash
    );
    documentsEntries := [];
  };

  // Store a new document (hash must be unique)
  public shared(msg) func storeDocument(hash: Text, fileName: Text) : async Result.Result<Document, Error> {
    // Get the actual caller
    let caller = msg.caller;
    
    // Check if caller is anonymous
    if (Principal.isAnonymous(caller)) {
      return #err(#NotAuthorized("Anonymous calls are not allowed"));
    };
    
    // Check if document already exists
    switch (documents.get(hash)) {
      case (?existing) {
        return #err(#AlreadyExists("Document with this hash already exists"));
      };
      case null {
        let now = Time.now();
        let doc: Document = {
          hash = hash;
          fileName = fileName;
          uploadedBy = caller;
          uploadedAt = now;
        };
        
        documents.put(hash, doc);
        return #ok(doc);
      };
    };
  };

  // Verify if a document with a specific hash exists
  public query func verifyDocument(hash: Text) : async Bool {
    return Option.isSome(documents.get(hash));
  };

  // Retrieve document metadata
  public query func getDocument(hash: Text) : async Result.Result<Document, Error> {
    switch (documents.get(hash)) {
      case (?doc) {
        return #ok(doc);
      };
      case null {
        return #err(#NotFound("Document not found"));
      };
    };
  };

  // Get all documents uploaded by a specific user
  public query func getUserDocuments(user: Principal) : async [Document] {
    var userDocs : [Document] = [];
    
    for (doc in documents.vals()) {
      if (Principal.equal(doc.uploadedBy, user)) {
        userDocs := Array.append(userDocs, [doc]);
      };
    };
    
    return userDocs;
  };

  // Delete a document (only by the owner)
  public shared(msg) func deleteDocument(hash: Text) : async Result.Result<(), Error> {
    let caller = msg.caller;
    
    switch (documents.get(hash)) {
      case (?doc) {
        if (Principal.equal(doc.uploadedBy, caller)) {
          ignore documents.remove(hash);
          return #ok();
        } else {
          return #err(#NotAuthorized("Only the document owner can delete it"));
        };
      };
      case null {
        return #err(#NotFound("Document not found"));
      };
    };
  };

  // For debugging purposes - get total document count
  public query func getDocumentCount() : async Nat {
    return documents.size();
  };
}
