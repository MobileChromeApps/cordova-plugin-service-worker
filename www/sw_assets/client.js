Clients = function(clientList) {
  this.clientList = clientList;
  return this;
};

// TODO: Add `options`.
Clients.prototype.getAll = function() {
  return this.clientList;
}

var clients = new Clients([]);

Client = function(url) {
  this.url = url;

  // Add this new client to the list of clients.
  clients.clientList.push(this);

  return this;
}

// TODO: Add `transfer`.
Client.prototype.postMessage = function(message) {
  postMessageInternal(Kamino.stringify(message));
}

