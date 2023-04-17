const express = require('express');
const xpath = require('xpath');
const dom = require('xmldom').DOMParser;
const fs = require('fs');
const app = express();
const port = 3000;

const xml = fs.readFileSync('/var/tmp/export.xml', 'utf8');
const doc = new dom().parseFromString(xml);

app.get('/showteam', async function (req, res) {
  const teamName = req.query.team;
//   const re = /^[A-Za-z]+$/g;
//   if ( ! re.test(teamName) ) {
// 	res.send("invalid team name");
// 	return;
//   }

  try {
	const nodes = xpath.select("/teams/team[name='" + teamName + "']/members/member/name/text()", doc);
	var responseHtml = "<ul>";
	nodes.forEach( (n) => responseHtml += "<li>" + n.toString() + "</li>" );
	responseHtml += "</ul>";
	res.send(responseHtml);
  } catch (e)  {
	res.send(e.message)
  }
});

app.listen(port, () => {
  console.log(`Listening on http://localhost:${port}`);
});