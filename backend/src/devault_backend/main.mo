actor DeVault {
  public func greet(name : Text) : async Text {
    return "Hello, " # name # "! Welcome to DeVault.";
  }
}
