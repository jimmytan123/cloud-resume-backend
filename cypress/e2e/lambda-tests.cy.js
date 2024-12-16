describe('AWS Lambda function tests', () => {
  const endpoint = '/update-view-count'; // API Gateway route

  it('should receive 201 response when making a POST request successfully', () => {
    cy.request('POST', endpoint).then((response) => {
      expect(response.status).to.eq(201);
      expect(response.body)
        .to.have.property('view_count')
        .and.to.be.a('number');
    });
  });
});
