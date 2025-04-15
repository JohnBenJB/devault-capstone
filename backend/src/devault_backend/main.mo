import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Buffer "mo:base/Buffer";
import Debug "mo:base/Debug";
import Error "mo:base/Error";
import Hash "mo:base/Hash";
import HashMap "mo:base/HashMap";
import Iter "mo:base/Iter";
import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import Option "mo:base/Option";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Time "mo:base/Time";
import TrieMap "mo:base/TrieMap";

// Define actor for DeVault canister
actor DeVault {
// Type definitions
public type FileId = Text;
public type FileInfo = {
  name : Text;
  contentType : Text;
  size : Nat;
  createdAt : Time.Time;
  owner : Principal;
  hash : Text
};

public type FileContent = {
  name : Text;
  content : [Nat8];
  contentType : Text;
  createdAt : Time.Time
};

public type UserProfile = {
  displayName : Text;
  bio : Text;
  email : Text;
  createdAt : Time.Time;
  lastLoginAt : Time.Time
};

public type StorageStats = {
  filesCount : Nat;
  totalStorage : Nat;
  storageLimit : Nat
};

public type Error = {
  #NotFound;
  #AlreadyExists;
  #NotAuthorized;
  #StorageLimitExceeded;
  #SystemError
};

// Constants
let DEFAULT_STORAGE_LIMIT : Nat = 1_073_741_824; // 1GB in bytes

// State variables
private stable var fileInfoEntries : [(FileId, FileInfo)] = [];
private stable var fileContentEntries : [(FileId, [Nat8])] = [];
private stable var userProfileEntries : [(Principal, UserProfile)] = [];
private stable var userStorageLimitEntries : [(Principal, Nat)] = [];

private var fileInfos = HashMap.HashMap<FileId, FileInfo>(0, Text.equal, Text.hash);
private var fileContents = HashMap.HashMap<FileId, [Nat8]>(0, Text.equal, Text.hash);
private var userProfiles = HashMap.HashMap<Principal, UserProfile>(0, Principal.equal, Principal.hash);
private var userStorageLimits = HashMap.HashMap<Principal, Nat>(0, Principal.equal, Principal.hash);

// Helper function to calculate SHA-256 hash (Note: simplified for example)
private func calculateHash(content : [Nat8]) : Text {
  // In a real implementation, you would use a proper SHA-256 library
  // This is just a placeholder
  return Blob.toHex(Blob.fromArray(content))
};

// Helper function to get caller's principal
private func getCaller() : Principal {
  return Principal.fromActor(DeVault)
};

// Initialize state from stable variables
system func preupgrade() {
  fileInfoEntries := Iter.toArray(fileInfos.entries());
  fileContentEntries := Iter.toArray(fileContents.entries());
  userProfileEntries := Iter.toArray(userProfiles.entries());
  userStorageLimitEntries := Iter.toArray(userStorageLimits.entries())
};

system func postupgrade() {
  fileInfos := HashMap.fromIter<FileId, FileInfo>(
    Iter.fromArray(fileInfoEntries),
    fileInfoEntries.size(),
    Text.equal,
    Text.hash
  );
  fileInfoEntries := [];

  fileContents := HashMap.fromIter<FileId, [Nat8]>(
    Iter.fromArray(fileContentEntries),
    fileContentEntries.size(),
    Text.equal,
    Text.hash
  );
  fileContentEntries := [];

  userProfiles := HashMap.fromIter<Principal, UserProfile>(
    Iter.fromArray(userProfileEntries),
    userProfileEntries.size(),
    Principal.equal,
    Principal.hash
  );
  userProfileEntries := [];

  userStorageLimits := HashMap.fromIter<Principal, Nat>(
    Iter.fromArray(userStorageLimitEntries),
    userStorageLimitEntries.size(),
    Principal.equal,
    Principal.hash
  );
  userStorageLimitEntries := []
};

// Store a file
public shared (msg) func storeFile(file : FileContent) : async Result.Result<FileInfo, Error> {
  let caller = msg.caller;

  if (Principal.isAnonymous(caller)) {
    return #err(#NotAuthorized)
  };

  // Calculate file size
  let fileSize = file.content.size();

  // Check if user has enough storage
  let userStats = await getUserStorageStats(caller);
  if (userStats.totalStorage + fileSize > userStats.storageLimit) {
    return #err(#StorageLimitExceeded)
  };

  // Calculate hash
  let hash = calculateHash(file.content);

  // Create file info
  let fileInfo : FileInfo = {
    name = file.name;
    contentType = file.contentType;
    size = fileSize;
    createdAt = file.createdAt;
    owner = caller;
    hash = hash
  };

  // Store file
  fileInfos.put(hash, fileInfo);
  fileContents.put(hash, file.content);

  // Update last login
  switch (userProfiles.get(caller)) {
    case (null) {
      // Create default profile if not exists
      let newProfile : UserProfile = {
        displayName = "DeVault User";
        bio = "";
        email = "";
        createdAt = Time.now();
        lastLoginAt = Time.now()
      };
      userProfiles.put(caller, newProfile)
    };
    case (?profile) {
      let updatedProfile : UserProfile = {
        displayName = profile.displayName;
        bio = profile.bio;
        email = profile.email;
        createdAt = profile.createdAt;
        lastLoginAt = Time.now()
      };
      userProfiles.put(caller, updatedProfile)
    }
  };

  return #ok(fileInfo)
};

// Get file info by hash
public query func getFileInfo(hash : FileId) : async Result.Result<FileInfo, Error> {
  switch (fileInfos.get(hash)) {
    case (null) {#err(#NotFound)};
    case (?info) {#ok(info)}
  }
};

// Get file content by hash (only for file owner)
public shared (msg) func getFileContent(hash : FileId) : async Result.Result<[Nat8], Error> {
  let caller = msg.caller;

  switch (fileInfos.get(hash)) {
    case (null) {
      #err(#NotFound) case (null) {#err(#NotFound)};
      case (?info) {
        // Check if caller is the owner
        if (Principal.notEqual(caller, info.owner)) {
          return #err(#NotAuthorized)
        };

        switch (fileContents.get(hash)) {
          case (null) {#err(#SystemError)}; // This shouldn't happen if data integrity is maintained
          case (?content) {#ok(content)}
        }
      }
    }
  };

  // Get all files for a user
  public shared (msg) func getUserFiles() : async [FileInfo] {
    let caller = msg.caller;

    if (Principal.isAnonymous(caller)) {
      return []
    };

    // Filter files owned by the caller
    let userFiles = Buffer.Buffer<FileInfo>(0);

    for ((_, info) in fileInfos.entries()) {
      if (Principal.equal(info.owner, caller)) {
        userFiles.add(info)
      }
    };

    return Buffer.toArray(userFiles)
  };

  // Delete a file
  public shared (msg) func deleteFile(hash : FileId) : async Result.Result<(), Error> {
    let caller = msg.caller;

    switch (fileInfos.get(hash)) {
      case (null) {#err(#NotFound)};
      case (?info) {
        // Check if caller is the owner
        if (Principal.notEqual(caller, info.owner)) {
          return #err(#NotAuthorized)
        };

        // Delete file info and content
        fileInfos.delete(hash);
        fileContents.delete(hash);

        return #ok(())
      }
    }
  };

  // Delete all files for a user
  public shared (msg) func deleteAllUserFiles() : async Result.Result<Nat, Error> {
    let caller = msg.caller;

    if (Principal.isAnonymous(caller)) {
      return #err(#NotAuthorized)
    };

    // Find all files owned by the caller
    let filesToDelete = Buffer.Buffer<FileId>(0);

    for ((id, info) in fileInfos.entries()) {
      if (Principal.equal(info.owner, caller)) {
        filesToDelete.add(id)
      }
    };

    // Delete all found files
    for (id in filesToDelete.vals()) {
      fileInfos.delete(id);
      fileContents.delete(id)
    };

    return #ok(filesToDelete.size())
  };

  // Verify if a file exists
  public query func verifyFile(hash : FileId) : async Result.Result<FileInfo, Error> {
    switch (fileInfos.get(hash)) {
      case (null) {#err(#NotFound)};
      case (?info) {
        // Return file info without requiring ownership
        // This allows public verification
        #ok(info)
      }
    }
  };

  // Get user profile
  public shared (msg) func getUserProfile() : async Result.Result<UserProfile, Error> {
    let caller = msg.caller;

    if (Principal.isAnonymous(caller)) {
      return #err(#NotAuthorized)
    };

    switch (userProfiles.get(caller)) {
      case (null) {
        // Create default profile if not exists
        let newProfile : UserProfile = {
          displayName = "DeVault User";
          bio = "";
          email = "";
          createdAt = Time.now();
          lastLoginAt = Time.now()
        };
        userProfiles.put(caller, newProfile);
        return #ok(newProfile)
      };
      case (?profile) {
        // Update last login
        let updatedProfile : UserProfile = {
          displayName = profile.displayName;
          bio = profile.bio;
          email = profile.email;
          createdAt = profile.createdAt;
          lastLoginAt = Time.now()
        };
        userProfiles.put(caller, updatedProfile);
        return #ok(updatedProfile)
      }
    }
  };

  // Update user profile
  public shared (msg) func updateUserProfile(profile : UserProfile) : async Result.Result<UserProfile, Error> {
    let caller = msg.caller;

    if (Principal.isAnonymous(caller)) {
      return #err(#NotAuthorized)
    };

    // Get existing profile or create a new one
    let existingProfile = switch (userProfiles.get(caller)) {
      case (null) {
        {
          displayName = "";
          bio = "";
          email = "";
          createdAt = Time.now();
          lastLoginAt = Time.now()
        }
      };
      case (?p) {p}
    };

    // Update profile with new values, keeping creation time
    let updatedProfile : UserProfile = {
      displayName = profile.displayName;
      bio = profile.bio;
      email = profile.email;
      createdAt = existingProfile.createdAt;
      lastLoginAt = Time.now()
    };

    userProfiles.put(caller, updatedProfile);
    return #ok(updatedProfile)
  };

  // Get user storage statistics
  public shared (msg) func getUserStorageStats(userPrincipal : Principal) : async StorageStats {
    let caller = msg.caller;
    let principal = if (Principal.isAnonymous(caller)) {
      // If anonymous, only show stats for the provided principal
      userPrincipal
    } else if (Principal.equal(caller, userPrincipal) or Principal.equal(caller, Principal.fromActor(DeVault))) {
      // If caller is the user or the canister itself, show stats for the provided principal
      userPrincipal
    } else {
      // Otherwise show stats for the caller
      caller
    };

    // Calculate total storage used
    var totalStorage : Nat = 0;
    var filesCount : Nat = 0;

    for ((_, info) in fileInfos.entries()) {
      if (Principal.equal(info.owner, principal)) {
        totalStorage += info.size;
        filesCount += 1
      }
    };

    // Get storage limit (default or custom)
    let storageLimit = switch (userStorageLimits.get(principal)) {
      case (null) {DEFAULT_STORAGE_LIMIT};
      case (?limit) {limit}
    };

    return {
      filesCount = filesCount;
      totalStorage = totalStorage;
      storageLimit = storageLimit
    }
  };

  // Set storage limit for a user (admin only)
  public shared (msg) func setUserStorageLimit(userPrincipal : Principal, limit : Nat) : async Result.Result<(), Error> {
    let caller = msg.caller;

    // Only the canister itself can set storage limits
    // In a real implementation, you would check if caller is an admin
    if (Principal.notEqual(caller, Principal.fromActor(DeVault))) {
      return #err(#NotAuthorized)
    };

    userStorageLimits.put(userPrincipal, limit);
    return #ok(())
  };

  // Generate a Candid interface for this canister
  public func generateCandidInterface() : async Text {
    return ""; // The Candid interface would be generated by the Motoko compiler
  }
}
