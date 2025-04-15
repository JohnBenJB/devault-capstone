import Principal "mo:base/Principal";
import Time "mo:base/Time";
import Nat8 "mo:base/Nat8";

module {
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
};
