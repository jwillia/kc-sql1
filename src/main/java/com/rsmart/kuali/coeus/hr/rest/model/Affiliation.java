package com.rsmart.kuali.coeus.hr.rest.model;

import javax.validation.Valid;
import javax.validation.constraints.NotNull;
import javax.xml.bind.annotation.XmlAccessType;
import javax.xml.bind.annotation.XmlAccessorType;
import javax.xml.bind.annotation.XmlAttribute;
import javax.xml.bind.annotation.XmlElement;
import javax.xml.bind.annotation.XmlRootElement;

@XmlAccessorType(XmlAccessType.FIELD)
@XmlRootElement(name = "affiliation")
public class Affiliation {

  @XmlAttribute(name = "default")
  protected boolean isDefault = false;
  @XmlAttribute
  protected boolean active = false;
  @XmlAttribute
  @NotNull
  protected String affiliationType = null;
  @XmlAttribute
  protected String campus = null;
  @XmlElement (name = "employment", type = Employment.class)
  @Valid
  protected Employment employment = null;

  public String getAffiliationType() {
    return affiliationType;
  }

  public void setAffiliationType(String affiliationType) {
    this.affiliationType = affiliationType;
  }

  public boolean isDefault() {
    return isDefault;
  }

  public void setDefault(boolean isDefault) {
    this.isDefault = isDefault;
  }

  public boolean isActive() {
    return active;
  }

  public void setActive(boolean active) {
    this.active = active;
  }

  public String getCampus() {
    return campus;
  }

  public void setCampus(String campus) {
    this.campus = campus;
  }
  
  public void setEmployment(Employment employment) {
    this.employment = employment;
  }
  
  public Employment getEmployment() {
    return employment;
  }

}