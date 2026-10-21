{
  secretRef = secretPath:
    if secretPath != null
    then {_secret = secretPath;}
    else null;
}
