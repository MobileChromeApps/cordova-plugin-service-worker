function sendResponse(url, body) {
    handleFetchResponse({
        url:url,
        status:200,
        status_message:'OK',
        header_list: {
            mime_type:'text/html'
        },
        type:'default',
        body:body
    });
}

function fetch_default(url) {
  console.log("In fetch_default");
  handleFetchDefault({url:url});
}
